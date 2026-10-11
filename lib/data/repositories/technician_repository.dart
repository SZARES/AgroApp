import '../../domain/models/incident_status.dart';
import '../../domain/models/parcel.dart';
import '../../domain/models/sync_op.dart';
import '../../domain/models/technician_case.dart';
import '../../utils/result.dart';
import 'case_reader.dart';
import 'incident_repository.dart' show PhotoUrlResolver;
import 'local_store.dart';
import 'replica_watch.dart';

/// The technician's cases, read from and written to the local replica.
///
/// Every write is saved on the device first and queued for the sync engine,
/// so the whole flow works offline in the field.
abstract class TechnicianRepository {
  /// Cases of the technician's zones: open ones first (most urgent, then most
  /// recent), closed ones last.
  Stream<List<TechnicianCase>> watchCases();

  /// One case with history, photos, recommendations and visit.
  Stream<TechnicianCaseDetail?> watchCase(String id);

  /// Parcels with their open case, for the map.
  Stream<TechnicianMapData> watchMap();

  /// Assistance types and subtypes from the synced catalogs.
  Stream<List<AssistanceCategoryOption>> watchAssistanceCatalog();

  /// reported -> under_review, assigned to the technician.
  Future<Result<void>> takeCase(String incidentId);

  /// Schedules (or reschedules) a visit and moves the case to
  /// visit_scheduled.
  Future<Result<void>> scheduleVisit(
    String incidentId, {
    required DateTime date,
    String? comment,
  });

  /// Saves an assistance of the case, with its recommendation when given.
  Future<Result<void>> registerAssistance(
    String incidentId,
    AssistanceDraft draft,
  );

  /// Leaves a recommendation for the farmer on the case.
  Future<Result<void>> addRecommendation(
    String incidentId, {
    required String text,
    DateTime? dueDate,
  });

  /// The technician records that the farmer applied the recommendation.
  Future<Result<void>> confirmRecommendation(String recommendationId);

  /// The technician marks whether the farmer followed the recommendation
  /// (can be changed later).
  Future<Result<void>> markRecommendationFollowed(
    String recommendationId, {
    required bool followed,
  });

  /// Moves the case to attended (and completes its scheduled visit).
  Future<Result<void>> markAttended(String incidentId, {String? comment});

  /// Moves the case to closed.
  Future<Result<void>> closeCase(String incidentId, {String? comment});

  /// Short-lived URL to read a private photo, or null when unavailable.
  Future<String?> photoUrl(String storagePath);
}

class LocalTechnicianRepository implements TechnicianRepository {
  LocalTechnicianRepository({
    required LocalStore store,
    required String technicianId,
    required PhotoUrlResolver photoUrlResolver,
    DateTime Function()? clock,
  }) : _store = store,
       _reader = CaseReader(store),
       _technicianId = technicianId,
       _photoUrl = photoUrlResolver,
       _clock = clock ?? DateTime.now;

  static const _listTables = [
    'incidents',
    'incident_photos',
    'parcels',
    'farmers',
    'profiles',
    'symptom_types',
    'crops',
  ];

  final LocalStore _store;
  final CaseReader _reader;
  final String _technicianId;
  final PhotoUrlResolver _photoUrl;
  final DateTime Function() _clock;

  // --- reads --------------------------------------------------------------

  @override
  Stream<List<TechnicianCase>> watchCases() =>
      watchDerived(_store, _listTables, _loadCases);

  @override
  Stream<TechnicianCaseDetail?> watchCase(String id) => watchDerived(
    _store,
    [..._listTables, ...caseDetailTables],
    () => _loadDetail(id),
  );

  @override
  Stream<TechnicianMapData> watchMap() =>
      watchDerived(_store, _listTables, () async {
        final cases = await _loadCases();
        final caseByParcel = <String, String>{};
        for (final c in cases) {
          if (c.isOpen) caseByParcel.putIfAbsent(c.parcelId, () => c.id);
        }
        final rows = await _store.list(
          'parcels',
          where: (r) => r['active'] != false,
        );
        final parcels = [
          for (final row in rows) ?Parcel.tryFromRow(row),
        ];
        return TechnicianMapData(parcels: parcels, caseByParcel: caseByParcel);
      });

  @override
  Stream<List<AssistanceCategoryOption>> watchAssistanceCatalog() =>
      watchDerived(_store, const [
        'assistance_categories',
        'assistance_subtypes',
      ], _loadCatalog);

  @override
  Future<String?> photoUrl(String storagePath) => _photoUrl(storagePath);

  Future<List<AssistanceCategoryOption>> _loadCatalog() async {
    final categories = await _store.list(
      'assistance_categories',
      where: (r) => r['active'] != false,
    );
    categories.sort(_byOrder);
    final subtypes = await _store.list(
      'assistance_subtypes',
      where: (r) => r['active'] != false,
    );
    subtypes.sort(_byOrder);
    return [
      for (final c in categories)
        AssistanceCategoryOption(
          id: '${c['id']}',
          name: '${c['name']}',
          subtypes: [
            for (final s in subtypes)
              if (s['category_id'] == c['id'])
                AssistanceSubtypeOption(id: '${s['id']}', name: '${s['name']}'),
          ],
        ),
    ];
  }

  Future<List<TechnicianCase>> _loadCases() async {
    final rows = await _store.list('incidents');
    final cases = [for (final row in rows) await _summary(row)];
    cases.sort((a, b) {
      if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
      final byPriority = b.priority.index.compareTo(a.priority.index);
      if (byPriority != 0) return byPriority;
      final aDate = a.reportedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.reportedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return cases;
  }

  Future<TechnicianCaseDetail?> _loadDetail(String id) async {
    final row = await _store.get('incidents', id);
    if (row == null || row['deleted_at'] != null) return null;
    final farmer = await _store.get('farmers', '${row['farmer_id']}');
    final profile = await _store.get('profiles', '${farmer?['user_id']}');
    return TechnicianCaseDetail(
      summary: await _summary(row),
      description: _nonEmpty(row['description']),
      farmerPhone: _nonEmpty(farmer?['phone']) ?? _nonEmpty(profile?['phone']),
      history: await _reader.history(id),
      photos: await _reader.photos(id),
      recommendations: await _reader.recommendations(id),
      visit: await _reader.visit(id),
    );
  }

  Future<TechnicianCase> _summary(Map<String, dynamic> row) async {
    final id = '${row['id']}';
    final symptom = await _store.get('symptom_types', '${row['symptom_type_id']}');
    final parcel = await _store.get('parcels', '${row['parcel_id']}');
    final crop = await _store.get('crops', '${row['crop_id']}');
    final farmer = await _store.get('farmers', '${row['farmer_id']}');
    final profile = await _store.get('profiles', '${farmer?['user_id']}');
    final photos = await _store.list(
      'incident_photos',
      where: (p) => p['incident_id'] == id,
    );
    return TechnicianCase(
      id: id,
      farmerId: '${row['farmer_id']}',
      farmerName: _nonEmpty(profile?['full_name']) ?? 'Agricultor',
      parcelId: '${row['parcel_id']}',
      parcelName: _nonEmpty(parcel?['name']) ?? 'Parcela',
      cropName: _nonEmpty(crop?['name']),
      symptom: _nonEmpty(symptom?['name']) ?? 'Problema en el cultivo',
      priority: CasePriority.parse(row['priority']),
      status: IncidentStatus.tryParse(row['status']) ?? IncidentStatus.reported,
      reportedAt: CaseReader.date(row['reported_at']),
      isPending: await _store.isPending('incidents', id),
      photoCount: photos.length,
    );
  }

  // --- writes -------------------------------------------------------------

  @override
  Future<Result<void>> takeCase(String incidentId) => _guard(() async {
    final row = await _openCase(incidentId);
    if (IncidentStatus.tryParse(row['status']) != IncidentStatus.reported) {
      throw const TechnicianException(TechnicianFailure.invalidTransition);
    }
    await _changeStatus(row, IncidentStatus.underReview, null);
  });

  @override
  Future<Result<void>> scheduleVisit(
    String incidentId, {
    required DateTime date,
    String? comment,
  }) => _guard(() async {
    final row = await _openCase(incidentId);
    final text = _nonEmpty(comment);
    final existing = await _scheduledVisits(incidentId);
    if (existing.isNotEmpty) {
      await _store.save(
        table: 'technical_assistance',
        id: '${existing.first['id']}',
        op: SyncOp.update,
        row: {'assistance_date': _day(date), 'observations': text},
      );
    } else {
      await _store.save(
        table: 'technical_assistance',
        id: _store.newId(),
        op: SyncOp.upsert,
        row: {
          ..._assistanceBase(row),
          'category_id': await _visitCategoryId(),
          'assistance_date': _day(date),
          'topic': 'Visita programada',
          'observations': text,
          'status': 'scheduled',
        },
      );
    }
    if (IncidentStatus.tryParse(row['status']) !=
        IncidentStatus.visitScheduled) {
      await _changeStatus(row, IncidentStatus.visitScheduled, text);
    }
  });

  @override
  Future<Result<void>> registerAssistance(
    String incidentId,
    AssistanceDraft draft,
  ) => _guard(() async {
    final row = await _openCase(incidentId);
    final observation = draft.observation.trim();
    if (observation.isEmpty) {
      throw const TechnicianException(TechnicianFailure.emptyText);
    }
    final category = await _store.get('assistance_categories', draft.categoryId);
    if (category == null) {
      throw const TechnicianException(TechnicianFailure.noCategory);
    }
    final today = _day(_clock());
    final fields = <String, dynamic>{
      'category_id': draft.categoryId,
      'subtype_id': draft.subtypeId,
      'assistance_date': today,
      'topic': category['name'],
      'observations': observation,
      'next_followup_date': ?(draft.nextReview == null
          ? null
          : _day(draft.nextReview!)),
      'status': 'completed',
    };

    // A scheduled visit becomes the assistance that was done in it.
    final visits = await _scheduledVisits(incidentId);
    final String assistanceId;
    if (visits.isNotEmpty) {
      assistanceId = '${visits.first['id']}';
      await _store.save(
        table: 'technical_assistance',
        id: assistanceId,
        op: SyncOp.update,
        row: fields,
      );
    } else {
      assistanceId = _store.newId();
      await _store.save(
        table: 'technical_assistance',
        id: assistanceId,
        op: SyncOp.upsert,
        row: {..._assistanceBase(row), ...fields},
      );
    }
    final text = draft.recommendation.trim();
    if (text.isNotEmpty) {
      await _saveRecommendation(
        row,
        assistanceId: assistanceId,
        text: text,
        dueDate: draft.nextReview,
      );
    }
  });

  @override
  Future<Result<void>> addRecommendation(
    String incidentId, {
    required String text,
    DateTime? dueDate,
  }) => _guard(() async {
    final row = await _openCase(incidentId);
    final clean = text.trim();
    if (clean.isEmpty) {
      throw const TechnicianException(TechnicianFailure.emptyText);
    }
    // A recommendation hangs from an assistance: reuse the latest one of the
    // case or record a short one.
    final assistances = await _store.list(
      'technical_assistance',
      where: (a) => a['incident_id'] == incidentId && a['status'] != 'cancelled',
    );
    assistances.sort(
      (a, b) => '${b['created_at'] ?? b['assistance_date']}'.compareTo(
        '${a['created_at'] ?? a['assistance_date']}',
      ),
    );
    final String assistanceId;
    if (assistances.isNotEmpty) {
      assistanceId = '${assistances.first['id']}';
    } else {
      assistanceId = _store.newId();
      await _store.save(
        table: 'technical_assistance',
        id: assistanceId,
        op: SyncOp.upsert,
        row: {
          ..._assistanceBase(row),
          'category_id': await _visitCategoryId(),
          'assistance_date': _day(_clock()),
          'topic': 'Recomendación',
          'status': 'completed',
        },
      );
    }
    await _saveRecommendation(
      row,
      assistanceId: assistanceId,
      text: clean,
      dueDate: dueDate,
    );
  });

  @override
  Future<Result<void>> confirmRecommendation(String recommendationId) =>
      _guard(() async {
        final recommendation = await _store.get(
          'recommendations',
          recommendationId,
        );
        if (recommendation == null) {
          throw const TechnicianException(TechnicianFailure.notFound);
        }
        final already = await _store.list(
          'recommendation_confirmations',
          where: (c) => c['recommendation_id'] == recommendationId,
        );
        if (already.isNotEmpty) return;
        await _store.save(
          table: 'recommendation_confirmations',
          id: _store.newId(),
          op: SyncOp.batch,
          row: {
            'recommendation_id': recommendationId,
            'farmer_id': recommendation['farmer_id'],
            'confirmed_at': _clock().toUtc().toIso8601String(),
            'comment': 'Confirmado por el técnico',
          },
        );
      });

  @override
  Future<Result<void>> markRecommendationFollowed(
    String recommendationId, {
    required bool followed,
  }) => _guard(() async {
    final recommendation = await _store.get('recommendations', recommendationId);
    if (recommendation == null) {
      throw const TechnicianException(TechnicianFailure.notFound);
    }
    // One mark per recommendation: reuse its row so the server upserts it.
    final existing = await _store.list(
      'recommendation_followups',
      where: (f) => f['recommendation_id'] == recommendationId,
    );
    await _store.save(
      table: 'recommendation_followups',
      id: existing.isEmpty ? _store.newId() : '${existing.first['id']}',
      op: SyncOp.upsert,
      row: {
        'recommendation_id': recommendationId,
        'farmer_id': recommendation['farmer_id'],
        'technician_id': _technicianId,
        'followed': followed,
      },
    );
  });

  @override
  Future<Result<void>> markAttended(String incidentId, {String? comment}) =>
      _guard(() async {
        final row = await _openCase(incidentId);
        for (final visit in await _scheduledVisits(incidentId)) {
          await _store.save(
            table: 'technical_assistance',
            id: '${visit['id']}',
            op: SyncOp.update,
            row: {'status': 'completed'},
          );
        }
        await _changeStatus(row, IncidentStatus.attended, _nonEmpty(comment));
      });

  @override
  Future<Result<void>> closeCase(String incidentId, {String? comment}) =>
      _guard(() async {
        final row = await _openCase(incidentId);
        await _changeStatus(row, IncidentStatus.closed, _nonEmpty(comment));
      });

  // --- helpers ------------------------------------------------------------

  Future<Result<void>> _guard(Future<void> Function() action) async {
    try {
      await action();
      return const Result.ok(null);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  Future<Map<String, dynamic>> _openCase(String incidentId) async {
    final row = await _store.get('incidents', incidentId);
    if (row == null || row['deleted_at'] != null) {
      throw const TechnicianException(TechnicianFailure.notFound);
    }
    if (IncidentStatus.tryParse(row['status']) == IncidentStatus.closed) {
      throw const TechnicianException(TechnicianFailure.invalidTransition);
    }
    return row;
  }

  /// Updates the case status (the server trigger writes the history row) and
  /// keeps a device-only history row so the comment shows immediately.
  Future<void> _changeStatus(
    Map<String, dynamic> row,
    IncidentStatus next,
    String? comment,
  ) async {
    final id = '${row['id']}';
    final now = _clock().toUtc().toIso8601String();
    await _store.save(
      table: 'incidents',
      id: id,
      op: SyncOp.update,
      row: {
        'status': next.wire,
        if (row['assigned_technician_id'] == null)
          'assigned_technician_id': _technicianId,
      },
    );
    await _store.putLocal(
      table: 'incident_status_history',
      id: '$localHistoryPrefix$id-${next.wire}',
      row: {
        'incident_id': id,
        'old_status': row['status'],
        'new_status': next.wire,
        'changed_by': _technicianId,
        'changed_at': now,
        'comment': comment,
      },
    );
  }

  Future<void> _saveRecommendation(
    Map<String, dynamic> incident, {
    required String assistanceId,
    required String text,
    DateTime? dueDate,
  }) {
    return _store.save(
      table: 'recommendations',
      id: _store.newId(),
      op: SyncOp.upsert,
      row: {
        'assistance_id': assistanceId,
        'farmer_id': incident['farmer_id'],
        'parcel_id': incident['parcel_id'],
        'description': text,
        'due_date': ?(dueDate == null ? null : _day(dueDate)),
        'created_by': _technicianId,
        'created_at': _clock().toUtc().toIso8601String(),
      },
    );
  }

  Map<String, dynamic> _assistanceBase(Map<String, dynamic> incident) => {
    'farmer_id': incident['farmer_id'],
    'parcel_id': incident['parcel_id'],
    'incident_id': incident['id'],
    'provider': 'AIDER',
    'technician_id': _technicianId,
    'created_by': _technicianId,
  };

  Future<List<Map<String, dynamic>>> _scheduledVisits(String incidentId) {
    return _store.list(
      'technical_assistance',
      where: (a) => a['incident_id'] == incidentId && a['status'] == 'scheduled',
    );
  }

  /// Assumption: the catalog has no "visit" type, so a name containing
  /// "visita" wins and otherwise the first category is used.
  Future<String> _visitCategoryId() async {
    final categories = await _store.list(
      'assistance_categories',
      where: (r) => r['active'] != false,
    );
    categories.sort(_byOrder);
    if (categories.isEmpty) {
      throw const TechnicianException(TechnicianFailure.noCategory);
    }
    final visit = categories.where(
      (c) => '${c['name']}'.toLowerCase().contains('visita'),
    );
    return '${(visit.isEmpty ? categories.first : visit.first)['id']}';
  }

  static int _byOrder(Map<String, dynamic> a, Map<String, dynamic> b) {
    final byOrder = _int(a['sort_order']).compareTo(_int(b['sort_order']));
    return byOrder != 0 ? byOrder : '${a['name']}'.compareTo('${b['name']}');
  }

  static int _int(Object? v) => v is num ? v.toInt() : 0;

  static String _day(DateTime date) {
    final d = date.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static String? _nonEmpty(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;
}
