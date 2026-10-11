import 'package:flutter/foundation.dart';

import 'geo_point.dart';

/// A piece of land of the signed-in farmer.
@immutable
class Parcel {
  const Parcel({
    required this.id,
    required this.name,
    this.areaHectares,
    this.center,
    this.polygon = const [],
    this.cropName,
    this.openIncidents = 0,
    this.pendingSync = false,
  });

  final String id;
  final String name;
  final double? areaHectares;

  /// `latitude`/`longitude` of the row; null when the farmer gave no location.
  final GeoPoint? center;

  /// Outline from `geometry` (closing point dropped); empty when unknown.
  final List<GeoPoint> polygon;

  /// Crop of the active cycle, when known.
  final String? cropName;
  final int openIncidents;

  /// True while the parcel has not reached the server yet.
  final bool pendingSync;

  bool get hasLocation => polygon.length >= 3 || center != null;

  Parcel copyWith({String? cropName, int? openIncidents, bool? pendingSync}) =>
      Parcel(
        id: id,
        name: name,
        areaHectares: areaHectares,
        center: center,
        polygon: polygon,
        cropName: cropName ?? this.cropName,
        openIncidents: openIncidents ?? this.openIncidents,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  /// Builds a parcel from a replica `parcels` row; null when it has no usable
  /// id or name.
  static Parcel? tryFromRow(Map<String, dynamic> row) {
    final id = row['id'];
    final name = row['name'];
    if (id is! String || name is! String || name.trim().isEmpty) return null;
    final latitude = _toDouble(row['latitude']);
    final longitude = _toDouble(row['longitude']);
    return Parcel(
      id: id,
      name: name.trim(),
      areaHectares: _toDouble(row['area']),
      center: latitude != null && longitude != null
          ? GeoPoint(latitude: latitude, longitude: longitude)
          : null,
      polygon: _polygonOf(row['geometry']),
    );
  }

  /// Reads a GeoJSON `Polygon` (`[lng, lat]` pairs); empty when invalid.
  static List<GeoPoint> _polygonOf(Object? geometry) {
    if (geometry is! Map || geometry['type'] != 'Polygon') return const [];
    final rings = geometry['coordinates'];
    if (rings is! List || rings.isEmpty || rings.first is! List) {
      return const [];
    }
    final points = <GeoPoint>[];
    for (final pair in rings.first as List) {
      if (pair is! List || pair.length < 2) return const [];
      final lng = _toDouble(pair[0]);
      final lat = _toDouble(pair[1]);
      if (lat == null || lng == null) return const [];
      points.add(GeoPoint(latitude: lat, longitude: lng));
    }
    if (points.length > 1 && points.first == points.last) points.removeLast();
    return points.length >= 3 ? List.unmodifiable(points) : const [];
  }

  static double? _toDouble(Object? value) => switch (value) {
    num() => value.toDouble(),
    String() => double.tryParse(value),
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is Parcel &&
      other.id == id &&
      other.name == name &&
      other.areaHectares == areaHectares &&
      other.center == center &&
      listEquals(other.polygon, polygon) &&
      other.cropName == cropName &&
      other.openIncidents == openIncidents &&
      other.pendingSync == pendingSync;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    areaHectares,
    center,
    Object.hashAll(polygon),
    cropName,
    openIncidents,
    pendingSync,
  );
}
