import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/technician_repository.dart';
import '../../../../domain/models/technician_farmer.dart';

/// The technician's farmers list, read from the local replica.
class TechnicianFarmersViewModel extends ChangeNotifier {
  TechnicianFarmersViewModel({required TechnicianRepository repository}) {
    _subscription = repository.watchFarmers().listen(
      (farmers) {
        _farmers = List.unmodifiable(farmers);
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

  late final StreamSubscription<List<TechnicianFarmer>> _subscription;

  List<TechnicianFarmer> _farmers = const [];
  bool _isLoading = true;
  bool _loadFailed = false;
  String? _selectedId;

  List<TechnicianFarmer> get farmers => _farmers;
  bool get isLoading => _isLoading;
  bool get loadFailed => _loadFailed;

  /// Farmer open in the console's main area; null shows a hint.
  String? get selectedId => _selectedId;

  void select(String? id) {
    if (id == _selectedId) return;
    _selectedId = id;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
