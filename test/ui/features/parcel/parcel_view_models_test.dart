import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/repositories/location_repository.dart';
import 'package:hackathon/domain/models/geo_point.dart';
import 'package:hackathon/domain/models/parcel.dart';
import 'package:hackathon/domain/models/parcel_failure.dart';
import 'package:hackathon/ui/features/parcel/view_models/add_parcel_view_model.dart';
import 'package:hackathon/ui/features/parcel/view_models/parcel_map_projection.dart';
import 'package:hackathon/ui/features/parcel/view_models/parcel_view_model.dart';
import 'package:hackathon/utils/result.dart';

import '../../../testing/home_fakes.dart';

void main() {
  group('ParcelViewModel', () {
    test('loads parcels, totals hectares and follows updates', () async {
      final repository = FakeParcelRepository(const [
        Parcel(id: 'a', name: 'A', areaHectares: 1.5),
        Parcel(id: 'b', name: 'B'),
      ]);
      final viewModel = ParcelViewModel(repository: repository);
      addTearDown(viewModel.dispose);
      expect(viewModel.isLoading, isTrue);

      await pumpEventQueue();
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.parcels, hasLength(2));
      expect(viewModel.totalHectares, 1.5);

      repository.emit(const [Parcel(id: 'a', name: 'A', areaHectares: 3)]);
      await pumpEventQueue();
      expect(viewModel.totalHectares, 3);
    });

    test('flags a failed load', () async {
      final repository = FakeParcelRepository();
      final viewModel = ParcelViewModel(repository: repository);
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      repository.emitError();
      await pumpEventQueue();

      expect(viewModel.loadFailed, isTrue);
    });
  });

  group('AddParcelViewModel', () {
    test('asks name, then area, then saves when there is no GPS', () async {
      final repository = FakeParcelRepository();
      final viewModel = AddParcelViewModel(repository: repository);

      await viewModel.next();
      expect(viewModel.error, AddParcelError.invalidName);

      viewModel.setName(' Campo ');
      expect(viewModel.error, isNull);
      await viewModel.next();
      expect(viewModel.step, AddParcelStep.area);

      viewModel.setArea('abc');
      await viewModel.next();
      expect(viewModel.error, AddParcelError.invalidArea);

      viewModel.setArea('1,5');
      await viewModel.next();

      expect(viewModel.saved?.name, 'Campo');
      expect(repository.added.single.area, 1.5);
      expect(repository.added.single.location, isNull);
    });

    test('asks location when available and saves it', () async {
      final repository = FakeParcelRepository();
      final viewModel = AddParcelViewModel(
        repository: repository,
        locationRepository: FakeLocationRepository(),
      );
      viewModel
        ..setName('Campo')
        ..setArea('2');
      await viewModel.next();
      await viewModel.next();
      expect(viewModel.step, AddParcelStep.location);

      await viewModel.useDeviceLocation();
      expect(viewModel.location, isNotNull);
      await viewModel.next();

      expect(viewModel.saved, isNotNull);
      expect(
        repository.added.single.location,
        const GeoPoint(latitude: -5.19, longitude: -80.63),
      );
    });

    test('can save without location and maps location errors', () async {
      final repository = FakeParcelRepository();
      final location = FakeLocationRepository(
        const Result.error(LocationFailure.permissionDenied),
      );
      final viewModel = AddParcelViewModel(
        repository: repository,
        locationRepository: location,
      );
      viewModel
        ..setName('Campo')
        ..setArea('2');
      await viewModel.next();
      await viewModel.next();

      await viewModel.useDeviceLocation();
      expect(viewModel.error, AddParcelError.locationDenied);

      await viewModel.next();
      expect(viewModel.saved, isNotNull);
      expect(repository.added.single.location, isNull);
    });

    test('back returns to the previous question', () async {
      final viewModel = AddParcelViewModel(repository: FakeParcelRepository());
      viewModel.setName('Campo');
      await viewModel.next();

      viewModel.back();

      expect(viewModel.step, AddParcelStep.name);
    });

    test('reports repository failures without finishing', () async {
      final repository = FakeParcelRepository()
        ..addResult = const Result.error(ParcelFailure.noZone);
      final viewModel = AddParcelViewModel(repository: repository);
      viewModel
        ..setName('Campo')
        ..setArea('2');
      await viewModel.next();
      await viewModel.next();

      expect(viewModel.saved, isNull);
      expect(viewModel.error, AddParcelError.noZone);
      expect(viewModel.isBusy, isFalse);
    });
  });

  group('projectParcels', () {
    test('is empty without any coordinates', () {
      final data = projectParcels(const [Parcel(id: 'a', name: 'A')]);

      expect(data.fields, isEmpty);
      expect(data.pins, isEmpty);
    });

    test('draws polygons inside the 0..1 map space', () {
      final data = projectParcels(const [
        Parcel(
          id: 'a',
          name: 'A',
          polygon: [
            GeoPoint(latitude: -5.0, longitude: -80.0),
            GeoPoint(latitude: -5.0, longitude: -79.9),
            GeoPoint(latitude: -5.1, longitude: -79.9),
          ],
        ),
      ]);

      expect(data.fields.single.points, hasLength(3));
      for (final p in data.fields.single.points) {
        expect(p.dx, inInclusiveRange(0, 1));
        expect(p.dy, inInclusiveRange(0, 1));
      }
      // North is up: the first point (lat -5.0) is above the last (lat -5.1).
      expect(
        data.fields.single.points.first.dy,
        lessThan(data.fields.single.points.last.dy),
      );
    });

    test(
      'falls back to a marker for a center-only parcel and pins incidents',
      () {
        final data = projectParcels(const [
          Parcel(
            id: 'a',
            name: 'A',
            center: GeoPoint(latitude: -5.1, longitude: -80.6),
            openIncidents: 2,
          ),
        ]);

        expect(data.fields.single.points, hasLength(4));
        expect(data.pins, hasLength(1));
        expect(data.pins.single.position.dx, closeTo(0.5, 1e-9));
      },
    );
  });
}
