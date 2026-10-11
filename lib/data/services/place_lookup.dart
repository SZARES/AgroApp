import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';

import '../../domain/models/geo_point.dart';
import '../../domain/models/place_label.dart';

/// Turns coordinates into a short address label for the UI.
abstract interface class PlaceLookup {
  Future<PlaceLabel?> lookup(GeoPoint point);
}

class DevicePlaceLookup implements PlaceLookup {
  DevicePlaceLookup({Geocoding? geocoding})
    : _geocoding = geocoding ?? Geocoding(locale: const Locale('es', 'PE'));

  final Geocoding _geocoding;

  @override
  Future<PlaceLabel?> lookup(GeoPoint point) async {
    try {
      final places = await _geocoding.placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (places.isEmpty) return _coordsFallback(point);
      return _fromPlacemark(places.first) ?? _coordsFallback(point);
    } on Object {
      return _coordsFallback(point);
    }
  }

  PlaceLabel? _fromPlacemark(Placemark place) {
    final street = _join([
      place.thoroughfare,
      place.subThoroughfare,
    ], separator: ' ');
    final title =
        _firstNonEmpty([
          street,
          place.name,
          place.subLocality,
          place.locality,
        ]) ??
        '';
    if (title.isEmpty) return null;

    final subtitle = _join([
      if (street.isNotEmpty) place.subLocality,
      place.locality,
      place.administrativeArea,
      place.country,
    ]);
    final cleanSubtitle = subtitle == title ? '' : subtitle;
    return PlaceLabel(title: title, subtitle: cleanSubtitle);
  }

  PlaceLabel _coordsFallback(GeoPoint point) => PlaceLabel(
    title: 'Punto en el mapa',
    subtitle:
        '${point.latitude.toStringAsFixed(5)}, '
        '${point.longitude.toStringAsFixed(5)}',
  );

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
        return trimmed;
      }
    }
    return null;
  }

  static String _join(Iterable<String?> parts, {String separator = ', '}) {
    return [
      for (final part in parts)
        if ((part?.trim().isNotEmpty ?? false) &&
            part!.trim().toLowerCase() != 'null')
          part.trim(),
    ].join(separator);
  }
}
