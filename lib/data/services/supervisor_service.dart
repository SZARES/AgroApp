/// Raw rows of a KPI view or table.
typedef RowList = List<Map<String, dynamic>>;

/// A failed supervisor dashboard request, in transport-neutral terms.
class SupervisorServiceException implements Exception {
  const SupervisorServiceException({
    this.statusCode,
    this.code,
    this.message,
    this.isNetwork = false,
  });

  final int? statusCode;
  final String? code;
  final String? message;

  /// The request never reached the server.
  final bool isNetwork;

  @override
  String toString() =>
      'SupervisorServiceException($statusCode, $code, $message, network=$isNetwork)';
}

/// Online-only reads of the KPI views and tables behind the supervisor
/// dashboard. Every method throws [SupervisorServiceException] on failure.
///
/// All sources are `security_invoker` views or RLS-protected tables, so the
/// signed-in supervisor only ever receives the zones they can access.
abstract interface class SupervisorService {
  /// `v_kpi_overview`: per-zone adoption/alert/assistance/response KPIs.
  Future<RowList> fetchZoneKpis();

  /// `v_zone_summary`: registered producers per zone (adoption denominator).
  Future<RowList> fetchZoneSummaries();

  /// `v_recommendation_completion`: issued/confirmed per zone.
  Future<RowList> fetchRecommendationCompletion();

  /// `v_crop_cycle_balance`: production/expenses per cycle (joined by parcel).
  Future<RowList> fetchCropCycleBalance();

  /// `parcels` (id, zone_id): the parcel -> zone join map.
  Future<RowList> fetchParcels();

  /// `technical_assistance` (technician_id, parcel_id): technician load.
  Future<RowList> fetchAssistances();

  /// `incidents` (assigned_technician_id, status, parcel_id): technician load.
  Future<RowList> fetchIncidents();

  /// `units` (id, name, abbreviation): production unit labels.
  Future<RowList> fetchUnits();
}
