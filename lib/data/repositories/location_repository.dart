import 'package:geolocator/geolocator.dart';

import '../../domain/models/geo_point.dart';
import '../../utils/result.dart';

/// Why the device position could not be read.
enum LocationFailure implements Exception {
  permissionDenied,
  serviceDisabled,
  unavailable,
}

/// Reads the device position (GPS). Implementations live behind this
/// interface so the UI never touches platform plugins.
abstract class LocationRepository {
  Future<Result<GeoPoint>> currentPosition();
}

/// [LocationRepository] backed by the device GPS (geolocator).
class DeviceLocationRepository implements LocationRepository {
  const DeviceLocationRepository({
    this.timeout = const Duration(seconds: 20),
    this.maxLastKnownAge = const Duration(minutes: 2),
  });

  final Duration timeout;

  /// How old the device's last known fix may be and still be used as-is.
  final Duration maxLastKnownAge;

  @override
  Future<Result<GeoPoint>> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const Result.error(LocationFailure.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const Result.error(LocationFailure.permissionDenied);
      }
      final lastKnown = await _recentLastKnownPosition();
      if (lastKnown != null) return Result.ok(lastKnown);
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return Result.ok(
        GeoPoint(latitude: position.latitude, longitude: position.longitude),
      );
    } on Object {
      return const Result.error(LocationFailure.unavailable);
    }
  }

  /// The device's cached fix when it is fresh enough, so a new GPS request
  /// (slow, and it hangs on some devices) is only made when really needed.
  Future<GeoPoint?> _recentLastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      final age = DateTime.now().difference(position.timestamp);
      if (age.isNegative || age > maxLastKnownAge) return null;
      return GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on Object {
      // Not supported on every platform (web); fall back to a fresh request.
      return null;
    }
  }
}
