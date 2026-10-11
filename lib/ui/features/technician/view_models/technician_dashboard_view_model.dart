import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/technician_repository.dart';
import '../../../../domain/models/technician_farmer.dart';

/// Numbers of the technician's home dashboard.
class TechnicianDashboardViewModel extends ChangeNotifier {
  TechnicianDashboardViewModel({required TechnicianRepository repository}) {
    _subscription = repository.watchKpis().listen(
      (kpis) {
        _kpis = kpis;
        _isLoading = false;
        _loadFailed = false;
        notifyListeners();
      },
      onError: (Object _) {
        _isLoading = false;
        _loadFailed = true;
        notifyListeners();
      },
    );
  }

  late final StreamSubscription<TechnicianKpis> _subscription;

  TechnicianKpis _kpis = const TechnicianKpis();
  bool _isLoading = true;
  bool _loadFailed = false;

  TechnicianKpis get kpis => _kpis;
  bool get isLoading => _isLoading;
  bool get loadFailed => _loadFailed;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
