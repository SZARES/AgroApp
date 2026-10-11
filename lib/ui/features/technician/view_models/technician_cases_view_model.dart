import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/technician_repository.dart';
import '../../../../domain/models/technician_case.dart';

/// The technician's alert inbox and map, read from the local replica.
class TechnicianCasesViewModel extends ChangeNotifier {
  TechnicianCasesViewModel({required TechnicianRepository repository})
    : _repository = repository {
    _casesSubscription = repository.watchCases().listen(
      (cases) {
        _cases = List.unmodifiable(cases);
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
    _mapSubscription = repository.watchMap().listen(
      (map) {
        _map = map;
        notifyListeners();
      },
      onError: (Object _) {
        // The list still works without the map.
      },
    );
  }

  final TechnicianRepository _repository;
  late final StreamSubscription<List<TechnicianCase>> _casesSubscription;
  late final StreamSubscription<TechnicianMapData> _mapSubscription;

  List<TechnicianCase> _cases = const [];
  TechnicianMapData _map = const TechnicianMapData();
  bool _isLoading = true;
  bool _loadFailed = false;
  String? _selectedId;

  List<TechnicianCase> get cases => _cases;
  TechnicianMapData get map => _map;
  bool get isLoading => _isLoading;
  bool get loadFailed => _loadFailed;

  /// Case open in the console's main area; null shows the map.
  String? get selectedId => _selectedId;

  int get openCount => _cases.where((c) => c.isOpen).length;

  void select(String? id) {
    if (id == _selectedId) return;
    _selectedId = id;
    notifyListeners();
  }

  Future<String?> photoUrl(String storagePath) =>
      _repository.photoUrl(storagePath);

  @override
  void dispose() {
    unawaited(_casesSubscription.cancel());
    unawaited(_mapSubscription.cancel());
    super.dispose();
  }
}
