import '../../domain/models/home_summary.dart';
import '../../domain/models/incident_status.dart';
import 'local_store.dart';
import 'replica_watch.dart';

/// Builds the farmer home summary from the local replica.
abstract class HomeRepository {
  Stream<HomeSummary> watchSummary();
}

class LocalHomeRepository implements HomeRepository {
  LocalHomeRepository({required LocalStore store, required String farmerId})
    : _store = store,
      _farmerId = farmerId;

  static const fertilizationCode = 'fertilization';

  final LocalStore _store;
  final String _farmerId;

  @override
  Stream<HomeSummary> watchSummary() => watchDerived(_store, const [
    'parcels',
    'farmers',
    'communities',
    'zones',
    'crop_cycles',
    'activity_types',
    'activities',
    'incidents',
    'recommendations',
    'recommendation_confirmations',
    'harvests',
  ], _load);

  Future<HomeSummary> _load() async {
    final parcels = await _store.list(
      'parcels',
      where: (r) => r['farmer_id'] == _farmerId && r['active'] != false,
    );
    parcels.sort(
      (a, b) =>
          '${a['created_at'] ?? '~'}'.compareTo('${b['created_at'] ?? '~'}'),
    );
    final parcelIds = {for (final p in parcels) p['id']};

    final cycleIds = {
      for (final c in await _store.list(
        'crop_cycles',
        where: (r) => parcelIds.contains(r['parcel_id']),
      ))
        c['id'],
    };
    final fertilizationIds = {
      for (final t in await _store.list(
        'activity_types',
        where: (r) => r['code'] == fertilizationCode,
      ))
        t['id'],
    };
    final fertilizations = await _store.list(
      'activities',
      where: (r) =>
          cycleIds.contains(r['crop_cycle_id']) &&
          fertilizationIds.contains(r['activity_type_id']),
    );
    final harvests = await _store.list(
      'harvests',
      where: (r) => parcelIds.contains(r['parcel_id']),
    );
    final weights = [
      for (final h in harvests) ?_toDouble(h['estimated_weight_kg']),
    ];

    return HomeSummary(
      parcelName: parcels.isEmpty ? null : '${parcels.first['name']}',
      parcelCount: parcels.length,
      hasLocation: parcels.any(
        (p) =>
            (p['latitude'] != null && p['longitude'] != null) ||
            p['geometry'] != null,
      ),
      locationLabel: await _locationLabel(),
      lastFertilization: _latest(fertilizations, 'activity_date'),
      nextRecommendation: await _nextRecommendation(),
      activeIncident: await _activeIncident(),
      harvestCount: harvests.length,
      productionKg: weights.isEmpty ? null : weights.reduce((a, b) => a + b),
    );
  }

  Future<String?> _locationLabel() async {
    final farmer = await _store.get('farmers', _farmerId);
    final communityId = farmer?['community_id'];
    if (communityId is! String) return null;
    final community = await _store.get('communities', communityId);
    if (community == null) return null;
    final zoneId = community['zone_id'];
    final zone = zoneId is String ? await _store.get('zones', zoneId) : null;
    final label = [
      zone?['name'],
      community['name'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return label.isEmpty ? null : label;
  }

  /// Unconfirmed recommendation: the one due soonest, else the newest.
  Future<String?> _nextRecommendation() async {
    final confirmed = {
      for (final c in await _store.list('recommendation_confirmations'))
        c['recommendation_id'],
    };
    final open = await _store.list(
      'recommendations',
      where: (r) => r['farmer_id'] == _farmerId && !confirmed.contains(r['id']),
    );
    if (open.isEmpty) return null;
    final dated = open.where((r) => r['due_date'] != null).toList()
      ..sort((a, b) => '${a['due_date']}'.compareTo('${b['due_date']}'));
    if (dated.isNotEmpty) return '${dated.first['description']}';
    open.sort(
      (a, b) =>
          '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}'),
    );
    return '${open.first['description']}';
  }

  /// Status of the most recently reported unresolved problem.
  Future<IncidentStatus?> _activeIncident() async {
    final open = await _store.list(
      'incidents',
      where: (r) =>
          r['farmer_id'] == _farmerId &&
          (IncidentStatus.tryParse(r['status'])?.isOpen ?? false),
    );
    if (open.isEmpty) return null;
    open.sort(
      (a, b) =>
          '${b['reported_at'] ?? ''}'.compareTo('${a['reported_at'] ?? ''}'),
    );
    return IncidentStatus.tryParse(open.first['status']);
  }

  DateTime? _latest(List<Map<String, dynamic>> rows, String column) {
    DateTime? latest;
    for (final row in rows) {
      final value = row[column];
      final date = value is String ? DateTime.tryParse(value) : null;
      if (date != null && (latest == null || date.isAfter(latest))) {
        latest = date;
      }
    }
    return latest;
  }

  double? _toDouble(Object? value) => switch (value) {
    num() => value.toDouble(),
    String() => double.tryParse(value),
    _ => null,
  };
}
