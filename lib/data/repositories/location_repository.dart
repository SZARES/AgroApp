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
  });

  final Duration timeout;

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
}
