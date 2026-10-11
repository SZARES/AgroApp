import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class ConnectivityService {
  Future<bool> isOnline();

  /// Emits whenever the device gains or loses a network connection.
  Stream<bool> get onStatusChange;
}

class DeviceConnectivityService implements ConnectivityService {
  DeviceConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async =>
      _hasConnection(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasConnection).distinct();

  /// Empty results mean "unknown" on some Android builds (especially without
  /// ACCESS_NETWORK_STATE) — treat as online so sync still attempts.
  bool _hasConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return true;
    return results.any((result) => result != ConnectivityResult.none);
  }
}
