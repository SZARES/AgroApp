import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/incident_repository.dart';
import '../../../../domain/models/incident.dart';

/// Live list of the farmer's reports ("Mis reportes").
class IncidentsViewModel extends ChangeNotifier {
  IncidentsViewModel({required IncidentRepository repository}) {
    _subscription = repository.watchIncidents().listen(
      (items) {
        _items = items;
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

  late final StreamSubscription<List<IncidentSummary>> _subscription;
  List<IncidentSummary> _items = const [];
  bool _isLoading = true;
  bool _loadFailed = false;

  List<IncidentSummary> get items => _items;
  bool get isLoading => _isLoading;
  bool get loadFailed => _loadFailed;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
