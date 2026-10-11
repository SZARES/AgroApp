import '../../domain/models/supervisor_dashboard.dart';
import '../services/supervisor_service.dart';

/// The supervisor's KPI dashboard. Online-only, read-only.
abstract interface class SupervisorRepository {
  /// Fetches every KPI source and aggregates it into a dashboard snapshot.
  Future<SupervisorDashboardData> loadDashboard();
}

/// Reads the KPI views/tables through [SupervisorService] and aggregates them.
class SupabaseSupervisorRepository implements SupervisorRepository {
  const SupabaseSupervisorRepository({required SupervisorService service})
      : _service = service;

  final SupervisorService _service;

  @override
  Future<SupervisorDashboardData> loadDashboard() async {
    final results = await Future.wait([
      _service.fetchZoneKpis(),
      _service.fetchZoneSummaries(),
      _service.fetchRecommendationCompletion(),
      _service.fetchCropCycleBalance(),
      _service.fetchParcels(),
      _service.fetchAssistances(),
      _service.fetchIncidents(),
      _service.fetchUnits(),
    ]);
    return SupervisorDashboardAggregator.aggregate(
      zoneKpis: results[0],
      zoneSummaries: results[1],
      recommendationCompletion: results[2],
      cropCycleBalance: results[3],
      parcels: results[4],
      assistances: results[5],
      incidents: results[6],
      units: results[7],
    );
  }
}

/// Pure, dependency-free aggregation from raw rows to a dashboard snapshot.
abstract final class SupervisorDashboardAggregator {
  static SupervisorDashboardData aggregate({
    required RowList zoneKpis,
    required RowList zoneSummaries,
    required RowList recommendationCompletion,
    required RowList cropCycleBalance,
    required RowList parcels,
    required RowList assistances,
    required RowList incidents,
    required RowList units,
  }) {
    final unitLabel = {
      for (final u in units)
        _str(u['id']): _nonEmpty(u['name']) ?? _nonEmpty(u['abbreviation']) ?? 'unidad',
    };
    final parcelZone = {
      for (final p in parcels) _str(p['id']): _str(p['zone_id']),
    };
    final registeredByZone = {
      for (final z in zoneSummaries) _str(z['zone_id']): _int(z['producers']),
    };

    // issued/confirmed per zone.
    final issuedByZone = <String, int>{};
    final confirmedByZone = <String, int>{};
    for (final r in recommendationCompletion) {
      final zone = _str(r['zone_id']);
      issuedByZone[zone] = (issuedByZone[zone] ?? 0) + _int(r['issued']);
      confirmedByZone[zone] =
          (confirmedByZone[zone] ?? 0) + _int(r['confirmed']);
    }

    // technician load, per zone (and rolled up globally below).
    final loadByZone = <String, Map<String, _LoadAcc>>{};
    Map<String, _LoadAcc> zoneLoad(String zone) =>
        loadByZone.putIfAbsent(zone, () => {});
    _LoadAcc tech(Map<String, _LoadAcc> byTech, Object? rawId) {
      final id = _str(rawId);
      return byTech.putIfAbsent(id, () => _LoadAcc(id));
    }

    for (final a in assistances) {
      final techId = a['technician_id'];
      if (techId == null) continue;
      final zone = parcelZone[_str(a['parcel_id'])] ?? '';
      tech(zoneLoad(zone), techId).assistance++;
    }
    for (final i in incidents) {
      final techId = i['assigned_technician_id'];
      if (techId == null) continue;
      final zone = parcelZone[_str(i['parcel_id'])] ?? '';
      final closed = _str(i['status']) == 'closed';
      final acc = tech(zoneLoad(zone), techId);
      if (closed) {
        acc.closed++;
      } else {
        acc.pending++;
      }
    }

    // production / expenses, per zone via the parcel join.
    final productionByZone = <String, Map<String, double>>{};
    final householdByZone = <String, Map<String, double>>{};
    final surplusByZone = <String, Map<String, double>>{};
    final expensesByZone = <String, double>{};
    for (final row in cropCycleBalance) {
      final zone = parcelZone[_str(row['parcel_id'])] ?? '';
      expensesByZone[zone] =
          (expensesByZone[zone] ?? 0) + _num(row['total_expenses']);
      final byUnit = row['production_by_unit'];
      if (byUnit is! List) continue;
      final production = productionByZone.putIfAbsent(zone, () => {});
      final household = householdByZone.putIfAbsent(zone, () => {});
      final surplus = surplusByZone.putIfAbsent(zone, () => {});
      for (final item in byUnit) {
        if (item is! Map) continue;
        final label = unitLabel[_str(item['unit_id'])] ?? 'unidad';
        _add(production, label, _num(item['total_quantity']));
        _add(household, label, _num(item['household_quantity']));
        _add(surplus, label, _num(item['surplus_quantity']));
      }
    }

    // Per-zone metrics.
    final byZone = <String, SupervisorMetrics>{};
    final zones = <ZoneOption>[];
    final globalZoneLoad = <String, _LoadAcc>{};
    for (final zoneLoadEntry in loadByZone.entries) {
      for (final acc in zoneLoadEntry.value.values) {
        final g = globalZoneLoad.putIfAbsent(acc.id, () => _LoadAcc(acc.id));
        g.assistance += acc.assistance;
        g.closed += acc.closed;
        g.pending += acc.pending;
      }
    }

    double weightedHours = 0;
    int weightSum = 0;
    final globalProduction = <String, double>{};
    final globalHousehold = <String, double>{};
    final globalSurplus = <String, double>{};
    double globalExpenses = 0;

    for (final row in zoneKpis) {
      final zoneId = _str(row['zone_id']);
      final attended = _int(row['attended_cases']);
      final hours = _numOrNull(row['avg_attention_hours']);
      if (hours != null && attended > 0) {
        weightedHours += hours * attended;
        weightSum += attended;
      }
      final zoneLoadMap = loadByZone[zoneId] ?? const <String, _LoadAcc>{};
      byZone[zoneId] = SupervisorMetrics(
        activeFarmers: _int(row['active_farmers']),
        registeredFarmers: registeredByZone[zoneId] ?? 0,
        openAlerts: _int(row['open_alerts']),
        closedAlerts: _int(row['closed_cases']),
        attendedCases: attended,
        assistanceCount: _int(row['technical_assistance_count']),
        issuedRecommendations: issuedByZone[zoneId] ?? 0,
        confirmedRecommendations: confirmedByZone[zoneId] ?? 0,
        avgResponseHours: hours,
        expensesByCurrency: _currencyMap(expensesByZone[zoneId] ?? 0),
        productionByUnit:
            Map.unmodifiable(productionByZone[zoneId] ?? const {}),
        householdByUnit: Map.unmodifiable(householdByZone[zoneId] ?? const {}),
        surplusByUnit: Map.unmodifiable(surplusByZone[zoneId] ?? const {}),
        technicianLoad: _toLoad(zoneLoadMap),
      );
      zones.add(ZoneOption(id: zoneId, name: _nonEmpty(row['zone_name']) ?? 'Zona'));

      _merge(globalProduction, productionByZone[zoneId]);
      _merge(globalHousehold, householdByZone[zoneId]);
      _merge(globalSurplus, surplusByZone[zoneId]);
      globalExpenses += expensesByZone[zoneId] ?? 0;
    }

    final global = SupervisorMetrics(
      activeFarmers:
          _sum(zoneKpis, (r) => _int(r['active_farmers'])),
      registeredFarmers:
          registeredByZone.values.fold(0, (a, b) => a + b),
      openAlerts: _sum(zoneKpis, (r) => _int(r['open_alerts'])),
      closedAlerts: _sum(zoneKpis, (r) => _int(r['closed_cases'])),
      attendedCases: _sum(zoneKpis, (r) => _int(r['attended_cases'])),
      assistanceCount:
          _sum(zoneKpis, (r) => _int(r['technical_assistance_count'])),
      issuedRecommendations:
          issuedByZone.values.fold(0, (a, b) => a + b),
      confirmedRecommendations:
          confirmedByZone.values.fold(0, (a, b) => a + b),
      avgResponseHours: weightSum == 0 ? null : weightedHours / weightSum,
      expensesByCurrency: _currencyMap(globalExpenses),
      productionByUnit: Map.unmodifiable(globalProduction),
      householdByUnit: Map.unmodifiable(globalHousehold),
      surplusByUnit: Map.unmodifiable(globalSurplus),
      technicianLoad: _toLoad(globalZoneLoad),
    );

    return SupervisorDashboardData(zones: zones, global: global, byZone: byZone);
  }

  static const _currency = 'PEN';

  static Map<String, double> _currencyMap(double total) =>
      total == 0 ? const {} : {_currency: total};

  static List<TechnicianLoad> _toLoad(Map<String, _LoadAcc> byTech) {
    final list = [
      for (final acc in byTech.values)
        TechnicianLoad(
          id: acc.id,
          label: 'Técnico ${acc.id.length > 4 ? acc.id.substring(0, 4) : acc.id}',
          assistanceCount: acc.assistance,
          closedCases: acc.closed,
          pendingCases: acc.pending,
        ),
    ];
    list.sort((a, b) => b.assistanceCount.compareTo(a.assistanceCount));
    return list;
  }

  static void _merge(Map<String, double> into, Map<String, double>? from) {
    if (from == null) return;
    for (final entry in from.entries) {
      into[entry.key] = (into[entry.key] ?? 0) + entry.value;
    }
  }

  /// Adds [value] to [map][label]; zero quantities are skipped so a unit with
  /// nothing to show does not clutter the dashboard.
  static void _add(Map<String, double> map, String label, double value) {
    if (value == 0) return;
    map[label] = (map[label] ?? 0) + value;
  }

  static int _sum(RowList rows, int Function(Map<String, dynamic>) pick) {
    var total = 0;
    for (final row in rows) {
      total += pick(row);
    }
    return total;
  }

  static String _str(Object? v) => v == null ? '' : '$v';

  static String? _nonEmpty(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;

  static int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static double _num(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  static double? _numOrNull(Object? v) {
    if (v == null) return null;
    return v is num ? v.toDouble() : double.tryParse('$v');
  }
}

class _LoadAcc {
  _LoadAcc(this.id);

  final String id;
  int assistance = 0;
  int closed = 0;
  int pending = 0;
}
