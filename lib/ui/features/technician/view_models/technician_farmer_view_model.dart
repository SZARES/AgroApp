import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/technician_repository.dart';
import '../../../../domain/models/technician_case.dart';
import '../../../../domain/models/technician_farmer.dart';
import '../../../../utils/result.dart';

/// One farmer's file and the assistance the technician can register for them.
class TechnicianFarmerViewModel extends ChangeNotifier {
  TechnicianFarmerViewModel({
    required TechnicianRepository repository,
    required this.farmerId,
  }) : _repository = repository {
    _detailSubscription = repository.watchFarmer(farmerId).listen(
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
    _catalogSubscription = repository.watchAssistanceCatalog().listen(
      (catalog) {
        _catalog = List.unmodifiable(catalog);
        notifyListeners();
      },
      onError: (Object _) {},
    );
  }

  final String farmerId;
  final TechnicianRepository _repository;
  late final StreamSubscription<TechnicianFarmerDetail?> _detailSubscription;
  late final StreamSubscription<List<AssistanceCategoryOption>>
  _catalogSubscription;

  TechnicianFarmerDetail? _detail;
  List<AssistanceCategoryOption> _catalog = const [];
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isBusy = false;
  bool _disposed = false;

  TechnicianFarmerDetail? get detail => _detail;
  List<AssistanceCategoryOption> get catalog => _catalog;
  bool get isLoading => _isLoading;
  bool get loadFailed => _loadFailed;

  /// True while an assistance is being saved on the device.
  bool get isBusy => _isBusy;

  /// Saves an assistance for the farmer outside any case. The parcel comes
  /// from [parcelId] or, when null, from the draft.
  Future<Result<void>> registerAssistance(
    AssistanceDraft draft, {
    String? parcelId,
  }) async {
    if (_isBusy) {
      return const Result.error(
        TechnicianException(TechnicianFailure.invalidTransition),
      );
    }
    _isBusy = true;
    notifyListeners();
    try {
      return await _repository.registerFieldAssistance(
        farmerId: farmerId,
        parcelId: parcelId ?? draft.parcelId,
        draft: draft,
      );
    } finally {
      _isBusy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_detailSubscription.cancel());
    unawaited(_catalogSubscription.cancel());
    super.dispose();
  }
}
