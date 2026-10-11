import 'package:flutter/foundation.dart';

import '../../../../data/repositories/supervisor_repository.dart';
import '../../../../domain/models/supervisor_dashboard.dart';

/// The supervisor dashboard: loads the KPI snapshot once and lets the user
/// filter it by zone. Online-only, read-only.
class SupervisorDashboardViewModel extends ChangeNotifier {
  SupervisorDashboardViewModel({required SupervisorRepository repository})
      : _repository = repository {
    load();
  }

  final SupervisorRepository _repository;

  SupervisorDashboardData _data = SupervisorDashboardData.empty;
  bool _loading = true;
  Object? _loadError;
  String? _zoneId;

  bool get loading => _loading;
  bool get hasLoadError => _loadError != null;
  List<ZoneOption> get zones => _data.zones;
  String? get selectedZoneId => _zoneId;

  /// The KPIs of the selected zone, or the global view.
  SupervisorMetrics get metrics => _data.current(_zoneId);

  /// Title of the current view ("Todas las zonas" or the zone name).
  String get scopeTitle {
    final id = _zoneId;
    if (id == null) return 'Todas las zonas';
    for (final zone in _data.zones) {
      if (zone.id == id) return zone.name;
    }
    return 'Todas las zonas';
  }

  bool get isEmpty => _data.global.isEmpty;

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      _data = await _repository.loadDashboard();
      // Keep the selection valid if zones changed between loads.
      if (_zoneId != null && !_data.byZone.containsKey(_zoneId)) {
        _zoneId = null;
      }
      _loadError = null;
    } catch (error) {
      _loadError = error;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> retry() => load();

  void selectZone(String? zoneId) {
    if (zoneId == _zoneId) return;
    _zoneId = zoneId;
    notifyListeners();
  }
}
