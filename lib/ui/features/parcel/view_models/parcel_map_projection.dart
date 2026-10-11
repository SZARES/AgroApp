import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/models/geo_point.dart';
import '../../../../domain/models/parcel.dart';
import '../../../core/widgets/field_map.dart';

/// Parcels and pins in the normalized (0..1) space [FieldMap] draws in.
typedef ParcelMapData = ({List<MapFieldShape> fields, List<MapPin> pins});

/// Half-size, in map space, of the square drawn for a parcel that only has a
/// center point.
const _markerHalfSize = 0.04;
const _margin = 0.12;

/// Projects the parcels' polygons (or, as fallback, their center points) so
/// they all fit the map, keeping the real proportions. Parcels without any
/// coordinates are left out. Open problems become pins on their parcel.
ParcelMapData projectParcels(List<Parcel> parcels) {
  final located = parcels.where((p) => p.hasLocation).toList();
  if (located.isEmpty) return (fields: const [], pins: const []);

  List<GeoPoint> outlineOf(Parcel p) =>
      p.polygon.length >= 3 ? p.polygon : [?p.center];
  final all = [for (final p in located) ...outlineOf(p)];

  final minLat = all.map((p) => p.latitude).reduce(math.min);
  final maxLat = all.map((p) => p.latitude).reduce(math.max);
  final minLng = all.map((p) => p.longitude).reduce(math.min);
  final maxLng = all.map((p) => p.longitude).reduce(math.max);
  final midLat = (minLat + maxLat) / 2;
  final midLng = (minLng + maxLng) / 2;

  // Longitude degrees shrink with latitude; compensate so shapes keep their
  // real proportions.
  final lngScale = math.cos(midLat * math.pi / 180).abs();
  final width = (maxLng - minLng) * lngScale;
  final height = maxLat - minLat;
  final extent = math.max(width, height);
  final scale = extent == 0 ? 0.0 : (1 - 2 * _margin) / extent;

  Offset project(GeoPoint p) => Offset(
    0.5 + (p.longitude - midLng) * lngScale * scale,
    0.5 - (p.latitude - midLat) * scale,
  );

  final fields = <MapFieldShape>[];
  final pins = <MapPin>[];
  for (final parcel in located) {
    if (parcel.polygon.length >= 3) {
      fields.add(
        MapFieldShape(
          name: parcel.name,
          points: [for (final p in parcel.polygon) project(p)],
        ),
      );
    } else {
      final c = project(parcel.center!);
      fields.add(
        MapFieldShape(
          name: parcel.name,
          points: [
            c + const Offset(-_markerHalfSize, -_markerHalfSize),
            c + const Offset(_markerHalfSize, -_markerHalfSize),
            c + const Offset(_markerHalfSize, _markerHalfSize),
            c + const Offset(-_markerHalfSize, _markerHalfSize),
          ],
        ),
      );
    }
    if (parcel.openIncidents > 0) {
      final anchor = parcel.center ?? parcel.polygon.first;
      pins.add(MapPin(position: project(anchor)));
    }
  }
  return (fields: fields, pins: pins);
}
