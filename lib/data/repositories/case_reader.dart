import '../../domain/models/incident.dart';
import '../../domain/models/incident_status.dart';
import '../sync/sync_engine.dart' show localPathKey;
import 'local_store.dart';

/// Tables a case's detail (history, photos, recommendations, visit) reads.
const caseDetailTables = [
  'incidents',
  'incident_photos',
  'incident_status_history',
  'technical_assistance',
  'recommendations',
  'recommendation_confirmations',
  'recommendation_followups',
  'visit_attendance_confirmations',
  'profiles',
];

/// Prefix of history rows written only on this device (the server creates the
/// real row through a trigger; the local one carries the technician comment).
const localHistoryPrefix = 'local-';

/// Reads the parts of a case that farmers and technicians both see.
class CaseReader {
  const CaseReader(this._store);

  final LocalStore _store;

  /// Status history, oldest first. A device-only row only shows while the
  /// server row for the same status has not arrived; once it has, the server
  /// row is kept and takes the device row's comment.
  Future<List<IncidentHistoryEntry>> history(String incidentId) async {
    final rows = await _store.list(
      'incident_status_history',
      where: (r) => r['incident_id'] == incidentId,
    );
    final local = {
      for (final r in rows)
        if ('${r['id']}'.startsWith(localHistoryPrefix))
          '${r['new_status']}': r,
    };
    final server = [
      for (final r in rows)
        if (!'${r['id']}'.startsWith(localHistoryPrefix)) r,
    ];
    final serverStatuses = {for (final r in server) '${r['new_status']}'};
    final merged = [
      for (final r in server)
        {
          ...r,
          if (_nonEmpty(r['comment']) == null &&
              _nonEmpty(local['${r['new_status']}']?['comment']) != null)
            'comment': local['${r['new_status']}']!['comment'],
        },
      for (final entry in local.entries)
        if (!serverStatuses.contains(entry.key)) entry.value,
    ]..sort((a, b) => _text(a['changed_at']).compareTo(_text(b['changed_at'])));

    final entries = <IncidentHistoryEntry>[];
    for (final h in merged) {
      final status = IncidentStatus.tryParse(h['new_status']);
      if (status == null) continue;
      entries.add(
        IncidentHistoryEntry(
          status: status,
          changedAt: date(h['changed_at']),
          changedByName: await profileName(h['changed_by']),
          comment: _nonEmpty(h['comment']),
        ),
      );
    }
    return entries;
  }

  Future<List<IncidentPhotoInfo>> photos(String incidentId) async {
    final rows = await _store.list(
      'incident_photos',
      where: (r) => r['incident_id'] == incidentId,
    );
    rows.sort((a, b) => _text(a['created_at']).compareTo(_text(b['created_at'])));
    return [
      for (final p in rows)
        IncidentPhotoInfo(
          id: '${p['id']}',
          storagePath: '${p['storage_path']}',
          localPath: _nonEmpty(p[localPathKey]),
        ),
    ];
  }

  /// Recommendations of every assistance linked to the case, newest first.
  Future<List<CaseRecommendation>> recommendations(String incidentId) async {
    final assistanceIds = {
      for (final a in await _assistances(incidentId)) '${a['id']}',
    };
    if (assistanceIds.isEmpty) return const [];
    final rows = await _store.list(
      'recommendations',
      where: (r) => assistanceIds.contains('${r['assistance_id']}'),
    );
    rows.sort((a, b) => _text(b['created_at']).compareTo(_text(a['created_at'])));
    final confirmations = await _store.list('recommendation_confirmations');
    final confirmed = {for (final c in confirmations) '${c['recommendation_id']}'};
    final followups = {
      for (final f in await _store.list('recommendation_followups'))
        '${f['recommendation_id']}': f,
    };
    return [
      for (final r in rows)
        CaseRecommendation(
          id: '${r['id']}',
          description: '${r['description']}',
          isConfirmed: confirmed.contains('${r['id']}'),
          followed: followups['${r['id']}']?['followed'] as bool?,
          dueDate: date(r['due_date']),
          createdAt: date(r['created_at']),
          isPending:
              await _store.isPending('recommendations', '${r['id']}') ||
              await _isConfirmationPending('${r['id']}', confirmations) ||
              (followups['${r['id']}'] != null &&
                  await _store.isPending(
                    'recommendation_followups',
                    '${followups['${r['id']}']!['id']}',
                  )),
        ),
    ];
  }

  /// The upcoming scheduled visit of the case (earliest first); when none is
  /// left, the most recent visit already done.
  Future<CaseVisit?> visit(String incidentId) async {
    final assistances = await _assistances(incidentId);
    final scheduled = [
      for (final a in assistances)
        if (a['status'] == 'scheduled' && date(a['assistance_date']) != null) a,
    ]..sort((a, b) => _text(a['assistance_date']).compareTo(_text(b['assistance_date'])));
    if (scheduled.isNotEmpty) return _toVisit(scheduled.first, completed: false);

    // A recommendation-only assistance is not a visit.
    final done = [
      for (final a in assistances)
        if (a['status'] == 'completed' &&
            a['provider'] == 'AIDER' &&
            a['topic'] != 'Recomendación' &&
            date(a['assistance_date']) != null)
          a,
    ]..sort((a, b) => _text(b['assistance_date']).compareTo(_text(a['assistance_date'])));
    if (done.isEmpty) return null;
    return _toVisit(done.first, completed: true);
  }

  Future<CaseVisit> _toVisit(
    Map<String, dynamic> row, {
    required bool completed,
  }) async {
    final id = '${row['id']}';
    final answers = await _store.list(
      'visit_attendance_confirmations',
      where: (r) => r['assistance_id'] == id,
    );
    return CaseVisit(
      date: date(row['assistance_date'])!,
      comment: _nonEmpty(row['observations']) ?? _nonEmpty(row['topic']),
      assistanceId: id,
      isCompleted: completed,
      attendance: answers.isEmpty
          ? null
          : VisitAttendance(
              arrived: answers.first['arrived'] == true,
              isPending: await _store.isPending(
                'visit_attendance_confirmations',
                '${answers.first['id']}',
              ),
            ),
    );
  }

  Future<List<Map<String, dynamic>>> _assistances(String incidentId) {
    return _store.list(
      'technical_assistance',
      where: (r) => r['incident_id'] == incidentId && r['status'] != 'cancelled',
    );
  }

  Future<bool> _isConfirmationPending(
    String recommendationId,
    List<Map<String, dynamic>> confirmations,
  ) async {
    for (final c in confirmations) {
      if ('${c['recommendation_id']}' == recommendationId) {
        return _store.isPending('recommendation_confirmations', '${c['id']}');
      }
    }
    return false;
  }

  Future<String?> profileName(Object? id) async {
    if (id is! String) return null;
    final profile = await _store.get('profiles', id);
    return _nonEmpty(profile?['full_name']);
  }

  /// Parses an ISO timestamp or a plain `yyyy-MM-dd` date.
  static DateTime? date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  static String _text(Object? v) => v is String ? v : '';

  static String? _nonEmpty(Object? v) =>
      v is String && v.trim().isNotEmpty ? v : null;
}
