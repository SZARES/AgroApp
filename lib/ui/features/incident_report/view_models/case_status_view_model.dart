import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/incident_repository.dart';
import '../../../../domain/models/incident.dart';

/// One report with its history and photos, read from the local replica.
class CaseStatusViewModel extends ChangeNotifier {
  CaseStatusViewModel({
    required IncidentRepository repository,
    required String incidentId,
  }) : _repository = repository {
    _subscription = repository
        .watchIncident(incidentId)
        .listen(
          (detail) {
            _detail = detail;
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

  final IncidentRepository _repository;
  late final StreamSubscription<IncidentDetail?> _subscription;
  IncidentDetail? _detail;
  bool _isLoading = true;
  bool _loadFailed = false;

  IncidentDetail? get detail => _detail;
  bool get isLoading => _isLoading;
  bool get loadFailed => _loadFailed;

  /// Signed URL for a photo that is not on this device.
  Future<String?> photoUrl(String storagePath) =>
      _repository.photoUrl(storagePath);

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
