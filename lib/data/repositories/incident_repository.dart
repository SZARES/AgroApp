import '../../domain/models/incident.dart';
import '../../domain/models/incident_status.dart';
import '../../domain/models/sync_op.dart';
import '../../utils/result.dart';
import '../sync/sync_engine.dart' show localPathKey;
import 'local_store.dart';
import 'replica_watch.dart';

/// Reads and writes the farmer's problem reports through the local replica.
abstract class IncidentRepository {
  /// Parcels the farmer can report on.
  Stream<List<IncidentParcel>> watchParcels();

  /// Symptom catalog (synced from the server), in display order.
  Stream<List<SymptomType>> watchSymptoms();

  /// Saves the report and its photo rows on the device; the sync engine
  /// uploads them later. Returns the new incident id.
  Future<Result<String>> submit(IncidentDraft draft);

  /// Every report of the farmer, newest first.
  Stream<List<IncidentSummary>> watchIncidents();

  /// One report with history and photos; null when it does not exist.
  Stream<IncidentDetail?> watchIncident(String id);

  /// Short-lived URL to read a private photo, or null when unavailable.
  Future<String?> photoUrl(String storagePath);
}

typedef PhotoUrlResolver = Future<String?> Function(String storagePath);

class LocalIncidentRepository implements IncidentRepository {
  LocalIncidentRepository({
    required LocalStore store,
    required String farmerId,
    required PhotoUrlResolver photoUrlResolver,
    DateTime Function()? clock,
  }) : _store = store,
       _farmerId = farmerId,
       _photoUrl = photoUrlResolver,
       _clock = clock ?? DateTime.now;

  static const _tables = [
    'incidents',
    'incident_photos',
    'incident_status_history',
    'symptom_types',
    'parcels',
    'profiles',
  ];

  final LocalStore _store;
  final String _farmerId;
  final PhotoUrlResolver _photoUrl;
  final DateTime Function() _clock;

  @override
  Stream<List<IncidentParcel>> watchParcels() => watchDerived(
    _store,
    const ['parcels'],
    () async {
      final rows = await _store.list(
        'parcels',
        where: (r) => r['farmer_id'] == _farmerId && r['active'] != false,
      );
      rows.sort(
        (a, b) =>
            '${a['created_at'] ?? '~'}'.compareTo('${b['created_at'] ?? '~'}'),
      );
      return [
        for (final r in rows)
          IncidentParcel(id: '${r['id']}', name: '${r['name']}'),
      ];
    },
  );

  @override
  Stream<List<SymptomType>>
  watchSymptoms() => watchDerived(_store, const ['symptom_types'], () async {
    final rows = await _store.list(
      'symptom_types',
      where: (r) => r['active'] != false,
    );
    rows.sort((a, b) {
      final byOrder = _int(a['sort_order']).compareTo(_int(b['sort_order']));
      return byOrder != 0 ? byOrder : '${a['name']}'.compareTo('${b['name']}');
    });
    return [
      for (final r in rows) SymptomType(id: '${r['id']}', name: '${r['name']}'),
    ];
  });

  @override
  Future<Result<String>> submit(IncidentDraft draft) async {
    try {
      if (draft.symptoms.isEmpty) {
        return const Result.error(IncidentException(IncidentFailure.noSymptom));
      }
      if (draft.photos.length > IncidentDraft.maxPhotos) {
        return const Result.error(
          IncidentException(IncidentFailure.tooManyPhotos),
        );
      }
      final parcel = await _store.get('parcels', draft.parcelId);
      if (parcel == null || parcel['farmer_id'] != _farmerId) {
        return const Result.error(IncidentException(IncidentFailure.noParcel));
      }
      final cycle = await _activeCycle(draft.parcelId);
      final cropId = cycle?['crop_id'] ?? await _onlyCropId();
      if (cropId == null) {
        return const Result.error(IncidentException(IncidentFailure.noCrop));
      }

      final now = _clock().toUtc();
      final incidentId = _store.newId();
      // The backend stores one main symptom; the others go in the description.
      final extra = draft.symptoms.skip(1).map((s) => s.name).toList();
      final text = draft.description.trim();
      final description = [
        if (extra.isNotEmpty) 'Otros síntomas: ${extra.join(', ')}.',
        if (text.isNotEmpty) text,
      ].join(' ');

      // Parent first, children after: the outbox keeps this order.
      await _store.save(
        table: 'incidents',
        id: incidentId,
        op: SyncOp.batch,
        row: {
          'parcel_id': draft.parcelId,
          'farmer_id': _farmerId,
          'crop_id': cropId,
          'crop_cycle_id': ?cycle?['id'],
          'symptom_type_id': draft.symptoms.first.id,
          'description': description.isEmpty ? null : description,
          'reported_at': now.toIso8601String(),
          'status': IncidentStatus.reported.wire,
          'priority': 'medium',
        },
      );
      for (final photo in draft.photos) {
        final photoId = _store.newId();
        await _store.save(
          table: 'incident_photos',
          id: photoId,
          op: SyncOp.batch,
          row: {
            'incident_id': incidentId,
            // The storage policy needs the farmer id as first path segment.
            'storage_path': '$_farmerId/incidents/$incidentId/$photoId.jpg',
            'width': photo.width,
            'height': photo.height,
            'size_bytes': photo.sizeBytes,
            'taken_at': now.toIso8601String(),
            // Local-only: the sync engine uploads this file, then drops it.
            localPathKey: photo.localPath,
          },
        );
      }
      return Result.ok(incidentId);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  @override
  Stream<List<IncidentSummary>> watchIncidents() =>
      watchDerived(_store, _tables, _loadSummaries);

  @override
  Stream<IncidentDetail?> watchIncident(String id) =>
      watchDerived(_store, _tables, () => _loadDetail(id));

  @override
  Future<String?> photoUrl(String storagePath) => _photoUrl(storagePath);

  Future<List<IncidentSummary>> _loadSummaries() async {
    final rows = await _store.list(
      'incidents',
      where: (r) => r['farmer_id'] == _farmerId,
    );
    rows.sort(
      (a, b) =>
          '${b['reported_at'] ?? ''}'.compareTo('${a['reported_at'] ?? ''}'),
    );
    return [for (final row in rows) await _summary(row)];
  }

  Future<IncidentDetail?> _loadDetail(String id) async {
    final row = await _store.get('incidents', id);
    if (row == null || row['deleted_at'] != null) return null;

    final history = await _store.list(
      'incident_status_history',
      where: (r) => r['incident_id'] == id,
    );
    history.sort(
      (a, b) =>
          '${a['changed_at'] ?? ''}'.compareTo('${b['changed_at'] ?? ''}'),
    );
    final entries = <IncidentHistoryEntry>[];
    for (final h in history) {
      final status = IncidentStatus.tryParse(h['new_status']);
      if (status == null) continue;
      entries.add(
        IncidentHistoryEntry(
          status: status,
          changedAt: _date(h['changed_at']),
          changedByName: await _profileName(h['changed_by']),
          comment: _nonEmpty(h['comment']),
        ),
      );
    }

    final photoRows = await _store.list(
      'incident_photos',
      where: (r) => r['incident_id'] == id,
    );
    photoRows.sort(
      (a, b) =>
          '${a['created_at'] ?? ''}'.compareTo('${b['created_at'] ?? ''}'),
    );
    final photos = [
      for (final p in photoRows)
        IncidentPhotoInfo(
          id: '${p['id']}',
          storagePath: '${p['storage_path']}',
          localPath: _nonEmpty(p[localPathKey]),
        ),
    ];

    return IncidentDetail(
      summary: await _summary(row),
      description: _nonEmpty(row['description']),
      history: entries,
      photos: photos,
    );
  }

  Future<IncidentSummary> _summary(Map<String, dynamic> row) async {
    final symptom = await _store.get(
      'symptom_types',
      '${row['symptom_type_id']}',
    );
    final parcel = await _store.get('parcels', '${row['parcel_id']}');
    return IncidentSummary(
      id: '${row['id']}',
      symptom: _nonEmpty(symptom?['name']) ?? 'Problema en el cultivo',
      parcelName: _nonEmpty(parcel?['name']) ?? 'Mi parcela',
      status: IncidentStatus.tryParse(row['status']) ?? IncidentStatus.reported,
      reportedAt: _date(row['reported_at']),
      isPending: await _store.isPending('incidents', '${row['id']}'),
    );
  }

  Future<Map<String, dynamic>?> _activeCycle(String parcelId) async {
    final cycles = await _store.list(
      'crop_cycles',
      where: (r) => r['parcel_id'] == parcelId && r['status'] == 'active',
    );
    if (cycles.isEmpty) return null;
    cycles.sort(
      (a, b) => '${b['planting_date'] ?? ''}'.compareTo(
        '${a['planting_date'] ?? ''}',
      ),
    );
    return cycles.first;
  }

  /// Assumption: with no active cycle, a catalog of exactly one crop decides.
  Future<Object?> _onlyCropId() async {
    final crops = await _store.list(
      'crops',
      where: (r) => r['active'] != false,
    );
    return crops.length == 1 ? crops.first['id'] : null;
  }

  Future<String?> _profileName(Object? id) async {
    if (id is! String) return null;
    final profile = await _store.get('profiles', id);
    return _nonEmpty(profile?['full_name']);
  }

  static int _int(Object? v) => v is num ? v.toInt() : 0;

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  static String? _nonEmpty(Object? v) =>
      v is String && v.trim().isNotEmpty ? v : null;
}
