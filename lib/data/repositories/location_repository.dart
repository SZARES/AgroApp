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
