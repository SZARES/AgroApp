import 'dart:async';

import 'package:hackathon/data/repositories/home_repository.dart';
import 'package:hackathon/data/repositories/location_repository.dart';
import 'package:hackathon/data/repositories/parcel_repository.dart';
import 'package:hackathon/domain/models/geo_point.dart';
import 'package:hackathon/domain/models/home_summary.dart';
import 'package:hackathon/domain/models/parcel.dart';
import 'package:hackathon/utils/result.dart';

class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository([HomeSummary initial = HomeSummary.empty])
    : _current = initial;

  HomeSummary _current;
  final _controller = StreamController<HomeSummary>.broadcast();

  void emit(HomeSummary summary) {
    _current = summary;
    _controller.add(summary);
  }

  void emitError() => _controller.addError(Exception('boom'));

  @override
  Stream<HomeSummary> watchSummary() async* {
    yield _current;
    yield* _controller.stream;
  }
}

class FakeParcelRepository implements ParcelRepository {
  FakeParcelRepository([List<Parcel> initial = const []]) : _current = initial;

  List<Parcel> _current;
  final _controller = StreamController<List<Parcel>>.broadcast();

  /// Result returned by [addParcel]; null saves and returns the parcel.
  Result<Parcel>? addResult;
  final List<({String name, double area, GeoPoint? location})> added = [];

  void emit(List<Parcel> parcels) {
    _current = parcels;
    _controller.add(parcels);
  }

  void emitError() => _controller.addError(Exception('boom'));

  @override
  Stream<List<Parcel>> watchParcels() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<Result<Parcel>> addParcel({
    required String name,
    required double areaHectares,
    GeoPoint? location,
  }) async {
    added.add((name: name, area: areaHectares, location: location));
    return addResult ??
        Result.ok(
          Parcel(
            id: 'new',
            name: name,
            areaHectares: areaHectares,
            center: location,
            pendingSync: true,
          ),
        );
  }
}

class FakeLocationRepository implements LocationRepository {
  FakeLocationRepository([this.result]);

  Result<GeoPoint>? result;

  @override
  Future<Result<GeoPoint>> currentPosition() async =>
      result ?? const Result.ok(GeoPoint(latitude: -5.19, longitude: -80.63));
}
