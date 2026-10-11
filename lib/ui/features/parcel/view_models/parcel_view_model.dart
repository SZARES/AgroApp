import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/parcel_repository.dart';
import '../../../../domain/models/parcel.dart';

class ParcelViewModel extends ChangeNotifier {
  ParcelViewModel({required ParcelRepository repository}) {
    _subscription = repository.watchParcels().listen(
      (parcels) {
        _parcels = parcels;
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

  late final StreamSubscription<List<Parcel>> _subscription;

  List<Parcel> get parcels => _parcels;
  List<Parcel> _parcels = const [];

  bool get isLoading => _isLoading;
  bool _isLoading = true;

  bool get loadFailed => _loadFailed;
  bool _loadFailed = false;

  /// Sum of the known areas, in hectares.
  double get totalHectares =>
      _parcels.fold(0, (sum, parcel) => sum + (parcel.areaHectares ?? 0));

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
