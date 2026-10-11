import 'package:supabase_flutter/supabase_flutter.dart';

import 'supervisor_service.dart';

/// Supabase implementation of [SupervisorService] (PostgREST over views/tables).
class SupabaseSupervisorService implements SupervisorService {
  const SupabaseSupervisorService(this._client);

  final SupabaseClient _client;

  @override
  Future<RowList> fetchZoneKpis() => _guard(
        () => _client
            .from('v_kpi_overview')
            .select(
              'zone_id, zone_name, active_farmers, open_alerts, '
              'attended_cases, closed_cases, technical_assistance_count, '
              'avg_attention_hours',
            ),
      );

  @override
  Future<RowList> fetchZoneSummaries() =>
      _guard(() => _client.from('v_zone_summary').select('zone_id, producers'));

  @override
  Future<RowList> fetchRecommendationCompletion() => _guard(
        () => _client
            .from('v_recommendation_completion')
            .select('zone_id, technician_id, issued, confirmed'),
      );

  @override
  Future<RowList> fetchCropCycleBalance() => _guard(
        () => _client
            .from('v_crop_cycle_balance')
            .select(
              'parcel_id, production_by_unit, total_expenses, sales_income',
            ),
      );

  @override
  Future<RowList> fetchParcels() =>
      _guard(() => _client.from('parcels').select('id, zone_id'));

  @override
  Future<RowList> fetchAssistances() => _guard(
        () => _client.from('technical_assistance').select(
              'technician_id, parcel_id',
            ),
      );

  @override
  Future<RowList> fetchIncidents() => _guard(
        () => _client.from('incidents').select(
              'assigned_technician_id, status, parcel_id',
            ),
      );

  @override
  Future<RowList> fetchUnits() =>
      _guard(() => _client.from('units').select('id, name, abbreviation'));

  Future<RowList> _guard(Future<dynamic> Function() action) async {
    try {
      final rows = await action();
      return [for (final row in rows as List) Map<String, dynamic>.from(row as Map)];
    } on SupervisorServiceException {
      rethrow;
    } on PostgrestException catch (error) {
      throw SupervisorServiceException(code: error.code, message: error.message);
    } on AuthException catch (error) {
      if (error is AuthRetryableFetchException) {
        throw SupervisorServiceException(message: error.message, isNetwork: true);
      }
      throw SupervisorServiceException(
        statusCode: int.tryParse(error.statusCode ?? ''),
        message: error.message,
      );
    } catch (error) {
      // Socket, HTTP client and timeout errors: the server was not reached.
      throw SupervisorServiceException(message: '$error', isNetwork: true);
    }
  }
}
