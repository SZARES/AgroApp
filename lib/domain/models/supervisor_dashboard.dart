import 'package:flutter/foundation.dart';

/// A quantity expressed in one concrete unit (never converted, per CONTEXT).
@immutable
class UnitQuantity {
  const UnitQuantity({required this.label, required this.quantity});

  final String label;
  final double quantity;

  @override
  String toString() => 'UnitQuantity($label, $quantity)';
}

/// Load of one technician (distribution of attention, never surveillance).
///
/// Under Option B the technician's name is unavailable because `profiles` RLS
/// hides non-farmer profiles from supervisors, so [label] is a masked id.
@immutable
class TechnicianLoad {
  const TechnicianLoad({
    required this.id,
    required this.label,
    required this.assistanceCount,
    required this.closedCases,
    required this.pendingCases,
  });

  final String id;
  final String label;
  final int assistanceCount;
  final int closedCases;
  final int pendingCases;

  @override
  String toString() => 'TechnicianLoad($label, a=$assistanceCount, '
      'c=$closedCases, p=$pendingCases)';
}

/// Aggregated KPIs for the whole accessible scope or for one zone.
@immutable
class SupervisorMetrics {
  const SupervisorMetrics({
    this.activeFarmers = 0,
    this.registeredFarmers = 0,
    this.openAlerts = 0,
    this.closedAlerts = 0,
    this.attendedCases = 0,
    this.assistanceCount = 0,
    this.issuedRecommendations = 0,
    this.confirmedRecommendations = 0,
    this.avgResponseHours,
    this.expensesByCurrency = const {},
    this.productionByUnit = const {},
    this.householdByUnit = const {},
    this.surplusByUnit = const {},
    this.technicianLoad = const [],
  });

  final int activeFarmers;
  final int registeredFarmers;
  final int openAlerts;
  final int closedAlerts;
  final int attendedCases;
  final int assistanceCount;
  final int issuedRecommendations;
  final int confirmedRecommendations;

  /// Attended-weighted average hours from report to attention; null when no
  /// attended case exists yet.
  final double? avgResponseHours;

  /// Total expenses per currency (default PEN). No conversion is applied.
  final Map<String, double> expensesByCurrency;

  /// Production, household consumption and surplus, keyed by unit label.
  final Map<String, double> productionByUnit;
  final Map<String, double> householdByUnit;
  final Map<String, double> surplusByUnit;

  final List<TechnicianLoad> technicianLoad;

  int get totalAlerts => openAlerts + closedAlerts;

  /// active_farmers / registered_farmers; null when there is nothing to divide.
  double? get adoptionRate =>
      registeredFarmers == 0 ? null : activeFarmers / registeredFarmers;

  /// closed / total incidents.
  double? get alertResolutionRate =>
      totalAlerts == 0 ? null : closedAlerts / totalAlerts;

  /// confirmed / issued recommendations.
  double? get recommendationRate =>
      issuedRecommendations == 0
          ? null
          : confirmedRecommendations / issuedRecommendations;

  bool get isEmpty =>
      activeFarmers == 0 &&
      registeredFarmers == 0 &&
      totalAlerts == 0 &&
      issuedRecommendations == 0 &&
      productionByUnit.isEmpty &&
      expensesByCurrency.isEmpty;

  List<UnitQuantity> _sorted(Map<String, double> source) {
    final entries = source.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entry in entries)
        UnitQuantity(label: entry.key, quantity: entry.value),
    ];
  }

  List<UnitQuantity> get production => _sorted(productionByUnit);
  List<UnitQuantity> get household => _sorted(householdByUnit);
  List<UnitQuantity> get surplus => _sorted(surplusByUnit);

  SupervisorMetrics copyWith({
    int? activeFarmers,
    int? registeredFarmers,
    int? openAlerts,
    int? closedAlerts,
    int? attendedCases,
    int? assistanceCount,
    int? issuedRecommendations,
    int? confirmedRecommendations,
    double? Function()? avgResponseHours,
    Map<String, double>? expensesByCurrency,
    Map<String, double>? productionByUnit,
    Map<String, double>? householdByUnit,
    Map<String, double>? surplusByUnit,
    List<TechnicianLoad>? technicianLoad,
  }) {
    return SupervisorMetrics(
      activeFarmers: activeFarmers ?? this.activeFarmers,
      registeredFarmers: registeredFarmers ?? this.registeredFarmers,
      openAlerts: openAlerts ?? this.openAlerts,
      closedAlerts: closedAlerts ?? this.closedAlerts,
      attendedCases: attendedCases ?? this.attendedCases,
      assistanceCount: assistanceCount ?? this.assistanceCount,
      issuedRecommendations:
          issuedRecommendations ?? this.issuedRecommendations,
      confirmedRecommendations:
          confirmedRecommendations ?? this.confirmedRecommendations,
      avgResponseHours: avgResponseHours != null
          ? avgResponseHours()
          : this.avgResponseHours,
      expensesByCurrency: expensesByCurrency ?? this.expensesByCurrency,
      productionByUnit: productionByUnit ?? this.productionByUnit,
      householdByUnit: householdByUnit ?? this.householdByUnit,
      surplusByUnit: surplusByUnit ?? this.surplusByUnit,
      technicianLoad: technicianLoad ?? this.technicianLoad,
    );
  }
}

/// One selectable zone in the dashboard filter.
@immutable
class ZoneOption {
  const ZoneOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// The dashboard snapshot: a global view plus one view per zone.
@immutable
class SupervisorDashboardData {
  const SupervisorDashboardData({
    required this.zones,
    required this.global,
    required this.byZone,
  });

  final List<ZoneOption> zones;
  final SupervisorMetrics global;
  final Map<String, SupervisorMetrics> byZone;

  static const empty = SupervisorDashboardData(
    zones: [],
    global: SupervisorMetrics(),
    byZone: {},
  );

  /// Metrics for [zoneId], or the global view when null / unknown.
  SupervisorMetrics current(String? zoneId) {
    if (zoneId == null) return global;
    return byZone[zoneId] ?? global;
  }
}
