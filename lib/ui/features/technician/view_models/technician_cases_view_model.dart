import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/technician_repository.dart';
import '../../../../domain/models/incident_status.dart';
import '../../../../domain/models/technician_case.dart';

/// Which cases the alert list shows.
enum CaseFilter {
  all('Todos'),
  urgent('Urgentes'),
  open('Abiertos'),
  scheduled('Visita programada'),
  closed('Cerrados');

  const CaseFilter(this.label);

  final String label;

  bool matches(TechnicianCase c) => switch (this) {
    CaseFilter.all => true,
    CaseFilter.urgent => c.isOpen && c.priority == CasePriority.high,
    CaseFilter.open => c.isOpen,
    CaseFilter.scheduled => c.status == IncidentStatus.visitScheduled,
    CaseFilter.closed => c.status == IncidentStatus.closed,
  };
}

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
  CaseFilter _filter = CaseFilter.all;

  List<TechnicianCase> get cases => _cases;

  CaseFilter get filter => _filter;

  /// The cases that match the current [filter], in the same order.
  List<TechnicianCase> get filteredCases =>
      _filter == CaseFilter.all
      ? _cases
      : List.unmodifiable(_cases.where(_filter.matches));

  /// How many cases each filter would show.
  int countFor(CaseFilter filter) =>
      _cases.where(filter.matches).length;

  /// Most urgent open cases still waiting for the technician (not yet
  /// attended), at most [limit].
  List<TechnicianCase> attentionCases({int limit = 5}) => [
    for (final c in _cases)
      if (c.isOpen && c.status != IncidentStatus.attended) c,
  ].take(limit).toList(growable: false);
  TechnicianMapData get map => _map;
  bool get isLoading => _isLoading;
  bool get loadFailed => _loadFailed;

  /// Case open in the console's main area; null shows the map.
  String? get selectedId => _selectedId;

  int get openCount => _cases.where((c) => c.isOpen).length;

  void setFilter(CaseFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    notifyListeners();
  }

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
