import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/location_repository.dart';
import '../../../../data/repositories/parcel_repository.dart';
import '../../../../data/services/place_lookup.dart';
import '../../../../domain/models/geo_point.dart';
import '../../../../domain/models/parcel.dart';
import '../../../../domain/models/parcel_failure.dart';
import '../../../../domain/models/place_label.dart';
import '../../../../utils/result.dart';

/// One question per screen.
enum AddParcelStep { name, area, location }

enum AddParcelError {
  invalidName,
  invalidArea,
  noZone,
  saveFailed,
  locationDenied,
  locationDisabled,
  locationUnavailable,
}

/// State of the "Agregar terreno" flow: name, then area, then (when the
/// device can give it) location, then save.
class AddParcelViewModel extends ChangeNotifier {
  AddParcelViewModel({
    required ParcelRepository repository,
    LocationRepository? locationRepository,
    PlaceLookup? placeLookup,
  }) : _repository = repository,
       _locationRepository = locationRepository,
       _placeLookup = placeLookup;

  final ParcelRepository _repository;
  final LocationRepository? _locationRepository;
  final PlaceLookup? _placeLookup;

  AddParcelStep get step => _step;
  AddParcelStep _step = AddParcelStep.name;

  String get name => _name;
  String _name = '';

  String get areaText => _areaText;
  String _areaText = '';

  GeoPoint? get location => _location;
  GeoPoint? _location;

  PlaceLabel? get placeLabel => _placeLabel;
  PlaceLabel? _placeLabel;

  bool get isLookingUpAddress => _isLookingUpAddress;
  bool _isLookingUpAddress = false;

  int _placeLookupGeneration = 0;

  AddParcelError? get error => _error;
  AddParcelError? _error;

  bool get isBusy => _isBusy;
  bool _isBusy = false;

  /// The saved parcel once the flow is done.
  Parcel? get saved => _saved;
  Parcel? _saved;

  /// Whether the location question is part of this flow.
  bool get canAskLocation => _locationRepository != null;

  void setName(String value) {
    _name = value;
    _clearError();
  }

  void setArea(String value) {
    _areaText = value;
    _clearError();
  }

  /// Hectares typed by the farmer; accepts "1,5" and "1.5". Null if invalid.
  double? get areaHectares {
    final value = double.tryParse(_areaText.trim().replaceAll(',', '.'));
    return value != null && value.isFinite && value > 0 ? value : null;
  }

  /// Moves to the next question, or saves after the last one.
  Future<void> next() async {
    switch (_step) {
      case AddParcelStep.name:
        if (_name.trim().isEmpty) return _fail(AddParcelError.invalidName);
        _go(AddParcelStep.area);
      case AddParcelStep.area:
        if (areaHectares == null) return _fail(AddParcelError.invalidArea);
        if (canAskLocation) {
          _go(AddParcelStep.location);
        } else {
          await save();
        }
      case AddParcelStep.location:
        await save();
    }
  }

  void back() {
    switch (_step) {
      case AddParcelStep.name:
        break;
      case AddParcelStep.area:
        _go(AddParcelStep.name);
      case AddParcelStep.location:
        _go(AddParcelStep.area);
    }
  }

  /// Reads the device position for the new land.
  Future<void> useDeviceLocation() async {
    final repository = _locationRepository;
    if (repository == null || _isBusy) return;
    _isBusy = true;
    _error = null;
    notifyListeners();
    final result = await repository.currentPosition();
    _isBusy = false;
    switch (result) {
      case Ok(:final value):
        await _applyLocation(value);
      case Error(:final error):
        _error = switch (error) {
          LocationFailure.permissionDenied => AddParcelError.locationDenied,
          LocationFailure.serviceDisabled => AddParcelError.locationDisabled,
          _ => AddParcelError.locationUnavailable,
        };
        notifyListeners();
    }
  }

  void clearLocation() {
    _placeLookupGeneration++;
    _location = null;
    _placeLabel = null;
    _isLookingUpAddress = false;
    notifyListeners();
  }

  /// Sets or moves the pin (GPS or tap on the map).
  void setLocation(GeoPoint point) {
    unawaited(_applyLocation(point));
  }

  Future<void> _applyLocation(GeoPoint point) async {
    final generation = ++_placeLookupGeneration;
    _location = point;
    _placeLabel = null;
    _error = null;
    _isLookingUpAddress = _placeLookup != null;
    notifyListeners();

    final lookup = _placeLookup;
    if (lookup == null) return;
    final label = await lookup.lookup(point);
    if (generation != _placeLookupGeneration) return;
    _placeLabel = label;
    _isLookingUpAddress = false;
    notifyListeners();
  }

  /// Saves locally (and queues the upload); [saved] is set on success.
  Future<void> save() async {
    final hectares = areaHectares;
    if (_isBusy) return;
    if (hectares == null) return _fail(AddParcelError.invalidArea);
    _isBusy = true;
    _error = null;
    notifyListeners();
    final result = await _repository.addParcel(
      name: _name.trim(),
      areaHectares: hectares,
      location: _location,
    );
    _isBusy = false;
    switch (result) {
      case Ok(:final value):
        _saved = value;
      case Error(:final error):
        _error = switch (error) {
          ParcelFailure.invalidName => AddParcelError.invalidName,
          ParcelFailure.invalidArea => AddParcelError.invalidArea,
          ParcelFailure.noZone => AddParcelError.noZone,
          _ => AddParcelError.saveFailed,
        };
    }
    notifyListeners();
  }

  void _go(AddParcelStep step) {
    _step = step;
    _error = null;
    notifyListeners();
  }

  void _fail(AddParcelError error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
