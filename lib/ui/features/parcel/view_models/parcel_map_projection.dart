import '../../../../domain/models/geo_point.dart';
import '../../../../domain/models/parcel.dart';
import '../../../core/widgets/field_map.dart';

/// Parcels and pins at their real coordinates, as [FieldMap] draws them.
typedef ParcelMapData = ({List<MapFieldShape> fields, List<MapPin> pins});

/// Places the parcels on the map by their polygon or, as fallback, their
/// center point. Parcels without any coordinates are left out. Open problems
/// become pins on their parcel.
ParcelMapData projectParcels(List<Parcel> parcels) {
  final fields = <MapFieldShape>[];
  final pins = <MapPin>[];
  for (final parcel in parcels) {
    if (!parcel.hasLocation) continue;
    final outline = parcel.polygon.length >= 3
        ? parcel.polygon
        : const <GeoPoint>[];
    final center = parcel.center ?? _centroid(outline);
    fields.add(
      MapFieldShape(name: parcel.name, center: center, outline: outline),
    );
    if (parcel.openIncidents > 0) pins.add(MapPin(position: center));
  }
  return (fields: fields, pins: pins);
}

GeoPoint _centroid(List<GeoPoint> points) => GeoPoint(
  latitude:
      points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
  longitude:
      points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
);
