import '../../domain/models/assistance.dart';
import '../../domain/models/incident.dart';
import '../../domain/models/record_support.dart';
import '../../domain/models/sync_op.dart';
import '../../utils/result.dart';
import '../sync/sync_engine.dart' show localPathKey;
import 'incident_repository.dart' show PhotoUrlResolver;
import 'local_store.dart';
import 'record_lookups.dart';
import 'replica_watch.dart';

/// Reads the farmer's technical assistances and saves external visits.
abstract class AssistanceRepository {
  /// Every assistance of the farmer (AIDER, SENASA, other), newest first.
  Stream<List<AssistanceSummary>> watchAssistances();

  /// One assistance with recommendations and documents; null when missing.
  Stream<AssistanceDetail?> watchAssistance(String id);

  /// Parcels and topic categories for the external visit flow.
  Stream<ExternalVisitCatalog> watchCatalog();

  /// Saves an external visit and its document photos on the device; the sync
  /// engine uploads them later. Returns the new assistance id.
  Future<Result<String>> saveExternalVisit(ExternalVisitDraft draft);

  /// Records that the farmer applied a recommendation (saved on the device,
  /// uploaded later).
  Future<Result<void>> confirmRecommendation(String recommendationId);

  /// Short-lived URL to read a private document, or null when unavailable.
  Future<String?> documentUrl(String storagePath);
}

class LocalAssistanceRepository implements AssistanceRepository {
  LocalAssistanceRepository({
    required LocalStore store,
    required String farmerId,
    required String userId,
    required PhotoUrlResolver documentUrlResolver,
    DateTime Function()? clock,
  }) : _store = store,
       _farmerId = farmerId,
       _userId = userId,
       _documentUrl = documentUrlResolver,
       _clock = clock ?? DateTime.now;

  static const _readTables = [
    'technical_assistance',
    'recommendations',
    'recommendation_confirmations',
    'assistance_documents',
    'assistance_categories',
    'assistance_subtypes',
    'profiles',
    'parcels',
  ];

  final LocalStore _store;
  final String _farmerId;
  final String _userId;
  final PhotoUrlResolver _documentUrl;
  final DateTime Function() _clock;

  @override
  Stream<List<AssistanceSummary>> watchAssistances() =>
      watchDerived(_store, _readTables, _loadSummaries);

  @override
  Stream<AssistanceDetail?> watchAssistance(String id) =>
      watchDerived(_store, _readTables, () => _loadDetail(id));

  @override
  Stream<ExternalVisitCatalog> watchCatalog() => watchDerived(
    _store,
    const ['parcels', 'assistance_categories'],
    () async {
      final parcels = await _store.list(
        'parcels',
        where: (r) => r['farmer_id'] == _farmerId && r['active'] != false,
      );
      parcels.sort(
        (a, b) =>
            '${a['created_at'] ?? '~'}'.compareTo('${b['created_at'] ?? '~'}'),
      );
      return ExternalVisitCatalog(
        parcels: [
          for (final p in parcels)
            IncidentParcel(id: '${p['id']}', name: '${p['name']}'),
        ],
        categories: await loadOptions(_store, 'assistance_categories'),
      );
    },
  );

  @override
  Future<Result<String>> saveExternalVisit(ExternalVisitDraft draft) async {
    try {
      if (draft.provider == AssistanceProvider.aider ||
          draft.photos.length > ExternalVisitDraft.maxPhotos) {
        return const Result.error(
          RecordException(RecordFailure.missingChoice),
        );
      }
      final parcel = await _store.get('parcels', draft.parcelId);
      final category = await _store.get(
        'assistance_categories',
        draft.categoryId,
      );
      if (parcel == null || parcel['farmer_id'] != _farmerId) {
        return const Result.error(RecordException(RecordFailure.noCycle));
      }
      if (category == null) {
        return const Result.error(
          RecordException(RecordFailure.missingChoice),
        );
      }
      final institution = draft.institutionName?.trim() ?? '';
      final comment = draft.comment?.trim() ?? '';
      final now = _clock().toUtc();
      final assistanceId = _store.newId();
      // Parent first, documents after: the outbox keeps this order.
      await _store.save(
        table: 'technical_assistance',
        id: assistanceId,
        op: SyncOp.batch,
        row: {
          'farmer_id': _farmerId,
          'parcel_id': draft.parcelId,
          'provider': draft.provider.wire,
          if (institution.isNotEmpty) 'institution_name': institution,
          'category_id': draft.categoryId,
          'assistance_date': dateOnly(draft.date),
          'topic': '${category['name']}',
          if (comment.isNotEmpty) 'observations': comment,
          'status': 'completed',
          'created_by': _userId,
        },
      );
      for (final photo in draft.photos) {
        final documentId = _store.newId();
        await _store.save(
          table: 'assistance_documents',
          id: documentId,
          op: SyncOp.batch,
          row: {
            'assistance_id': assistanceId,
            // The storage policy needs the farmer id as first path segment.
            'storage_path':
                '$_farmerId/external-documents/$assistanceId/$documentId.jpg',
            'kind': 'external_sheet',
            'created_at': now.toIso8601String(),
            // Local-only: the sync engine uploads this file, then drops it.
            localPathKey: photo.localPath,
          },
        );
      }
      return Result.ok(assistanceId);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  @override
  Future<Result<void>> confirmRecommendation(String recommendationId) async {
    try {
      final recommendation = await _store.get(
        'recommendations',
        recommendationId,
      );
      if (recommendation == null || recommendation['farmer_id'] != _farmerId) {
        return const Result.error(RecordException(RecordFailure.storage));
      }
      final already = await _store.list(
        'recommendation_confirmations',
        where: (c) => c['recommendation_id'] == recommendationId,
      );
      if (already.isNotEmpty) return const Result.ok(null);
      await _store.save(
        table: 'recommendation_confirmations',
        id: _store.newId(),
        op: SyncOp.batch,
        row: {
          'recommendation_id': recommendationId,
          'farmer_id': _farmerId,
          'confirmed_at': _clock().toUtc().toIso8601String(),
        },
      );
      return const Result.ok(null);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  @override
  Future<String?> documentUrl(String storagePath) => _documentUrl(storagePath);

  Future<List<AssistanceSummary>> _loadSummaries() async {
    final rows = await _store.list(
      'technical_assistance',
      where: (r) => r['farmer_id'] == _farmerId,
    );
    rows.sort((a, b) {
      final byDate = '${b['assistance_date'] ?? ''}'.compareTo(
        '${a['assistance_date'] ?? ''}',
      );
      return byDate != 0
          ? byDate
          : '${b['created_at'] ?? '~'}'.compareTo('${a['created_at'] ?? '~'}');
    });
    return [for (final row in rows) await _summary(row)];
  }

  Future<AssistanceDetail?> _loadDetail(String id) async {
    final row = await _store.get('technical_assistance', id);
    if (row == null || row['deleted_at'] != null) return null;
    if (row['farmer_id'] != _farmerId) return null;

    final parcel = await _store.get('parcels', '${row['parcel_id']}');
    final category = await _store.get(
      'assistance_categories',
      '${row['category_id']}',
    );

    final recRows = await _store.list(
      'recommendations',
      where: (r) => r['assistance_id'] == id,
    );
    recRows.sort(
      (a, b) =>
          '${a['created_at'] ?? ''}'.compareTo('${b['created_at'] ?? ''}'),
    );
    final confirmations = await _store.list('recommendation_confirmations');
    final confirmedIds = {
      for (final c in confirmations) '${c['recommendation_id']}',
    };
    final recommendations = <AssistanceRecommendation>[];
    for (final r in recRows) {
      final recId = '${r['id']}';
      var pending = await _store.isPending('recommendations', recId);
      for (final c in confirmations) {
        if ('${c['recommendation_id']}' == recId) {
          pending =
              pending ||
              await _store.isPending(
                'recommendation_confirmations',
                '${c['id']}',
              );
        }
      }
      recommendations.add(
        AssistanceRecommendation(
          id: recId,
          description: '${r['description']}',
          dueDate: parseDate(r['due_date']),
          isConfirmed: confirmedIds.contains(recId),
          isPending: pending,
        ),
      );
    }

    final docRows = await _store.list(
      'assistance_documents',
      where: (r) => r['assistance_id'] == id,
    );
    docRows.sort(
      (a, b) =>
          '${a['created_at'] ?? ''}'.compareTo('${b['created_at'] ?? ''}'),
    );

    return AssistanceDetail(
      summary: await _summary(row),
      parcelName: nonEmptyText(parcel?['name']) ?? 'Mi parcela',
      categoryName: nonEmptyText(category?['name']),
      observations: nonEmptyText(row['observations']),
      nextFollowup: parseDate(row['next_followup_date']),
      recommendations: recommendations,
      documents: [
        for (final d in docRows)
          AssistanceDocumentInfo(
            id: '${d['id']}',
            storagePath: '${d['storage_path']}',
            localPath: nonEmptyText(d[localPathKey]),
            comment: nonEmptyText(d['comment']),
          ),
      ],
    );
  }

  Future<AssistanceSummary> _summary(Map<String, dynamic> row) async {
    final technician = row['technician_id'] == null
        ? null
        : await _store.get('profiles', '${row['technician_id']}');
    final subtype = row['subtype_id'] == null
        ? null
        : await _store.get('assistance_subtypes', '${row['subtype_id']}');
    final category = await _store.get(
      'assistance_categories',
      '${row['category_id']}',
    );
    final id = '${row['id']}';
    var pending = await _store.isPending('technical_assistance', id);
    final documents = await _store.list(
      'assistance_documents',
      where: (r) => r['assistance_id'] == id,
    );
    for (final d in documents) {
      pending =
          pending || await _store.isPending('assistance_documents', '${d['id']}');
    }
    return AssistanceSummary(
      id: id,
      provider:
          AssistanceProvider.tryParse(row['provider']) ??
          AssistanceProvider.aider,
      status:
          AssistanceStatus.tryParse(row['status']) ??
          AssistanceStatus.completed,
      date: parseDate(row['assistance_date']),
      topic:
          nonEmptyText(row['topic']) ??
          nonEmptyText(subtype?['name']) ??
          nonEmptyText(category?['name']) ??
          'Asistencia técnica',
      technicianName: nonEmptyText(technician?['full_name']),
      institutionName: nonEmptyText(row['institution_name']),
      isPending: pending,
    );
  }
}
