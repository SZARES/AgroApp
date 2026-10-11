import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/domain/models/geo_point.dart';
import 'package:hackathon/domain/models/parcel.dart';

void main() {
  Map<String, dynamic> row([Map<String, dynamic> extra = const {}]) => {
    'id': 'p1',
    'name': ' Campo ',
    'area': '1.5',
    'latitude': -5.1,
    'longitude': '-80.6',
    ...extra,
  };

  test('reads center and area, tolerating numeric strings', () {
    final parcel = Parcel.tryFromRow(row())!;

    expect(parcel.name, 'Campo');
    expect(parcel.areaHectares, 1.5);
    expect(parcel.center, const GeoPoint(latitude: -5.1, longitude: -80.6));
    expect(parcel.polygon, isEmpty);
    expect(parcel.hasLocation, isTrue);
  });

  test('reads a GeoJSON polygon as lng,lat and drops the closing point', () {
    final parcel = Parcel.tryFromRow(
      row({
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [-80.0, -5.0],
              [-79.9, -5.0],
              [-79.9, -5.1],
              [-80.0, -5.0],
            ],
          ],
        },
      }),
    )!;

    expect(parcel.polygon, hasLength(3));
    expect(
      parcel.polygon.first,
      const GeoPoint(latitude: -5.0, longitude: -80.0),
    );
  });

  test('ignores malformed geometry and rows without id or name', () {
    expect(
      Parcel.tryFromRow(
        row({
          'geometry': {'type': 'Point'},
        }),
      )!.polygon,
      isEmpty,
    );
    expect(
      Parcel.tryFromRow(
        row({
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                ['x', 1],
              ],
            ],
          },
        }),
      )!.polygon,
      isEmpty,
    );
    expect(Parcel.tryFromRow({'id': 'p', 'name': ' '}), isNull);
    expect(Parcel.tryFromRow({'name': 'A'}), isNull);
  });

  test('has no location without coordinates', () {
    expect(Parcel.tryFromRow({'id': 'p', 'name': 'A'})!.hasLocation, isFalse);
  });
}
