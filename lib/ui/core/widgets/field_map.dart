import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../config/map_config.dart';
import '../../../domain/models/geo_point.dart';

/// A field on the map, at its real coordinates.
@immutable
class MapFieldShape {
  const MapFieldShape({
    required this.name,
    required this.center,
    this.outline = const [],
  });

  final String name;

  /// Where the field's label goes.
  final GeoPoint center;

  /// The field's boundary; empty when only [center] is known.
  final List<GeoPoint> outline;

  @override
  bool operator ==(Object other) =>
      other is MapFieldShape &&
      other.name == name &&
      other.center == center &&
      listEquals(other.outline, outline);

  @override
  int get hashCode => Object.hash(name, center, Object.hashAll(outline));
}

/// An incident pin at its real coordinates.
@immutable
class MapPin {
  const MapPin({required this.position, this.resolved = false, this.id});

  final GeoPoint position;

  /// Identifies the pin in [FieldMap.onPinTap]; null for pins that do nothing.
  final String? id;

  /// Resolved incidents are drawn muted so open ones stand out.
  final bool resolved;

  @override
  bool operator ==(Object other) =>
      other is MapPin &&
      other.position == position &&
      other.resolved == resolved &&
      other.id == id;

  @override
  int get hashCode => Object.hash(position, resolved, id);
}

const _accent = Color(0xFFF0701E);
const _fieldFill = Color(0x66F5B73B);
const _pinColor = Color(0xFFE53935);
const _panelColor = Color(0xEBFFFFFF);
const _basemapFallback = Color(0xFF4A6B36);

const _panelDecoration = BoxDecoration(
  color: _panelColor,
  borderRadius: BorderRadius.all(Radius.circular(16)),
  boxShadow: [
    BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
  ],
);

LatLng _latLng(GeoPoint point) => LatLng(point.latitude, point.longitude);

/// Satellite map with the fields and incident pins at their real location.
///
/// Tiles need a connection; without one the fields are still drawn, over a
/// plain background.
class FieldMap extends StatefulWidget {
  const FieldMap({
    super.key,
    required this.fields,
    this.pins = const [],
    this.onAddField,
    this.onPinTap,
    this.onMapTap,
    this.showIncidentSummary = true,
    this.height = 360,
  });

  final List<MapFieldShape> fields;
  final List<MapPin> pins;
  final VoidCallback? onAddField;

  /// Called with the id of a tapped pin that has one.
  final ValueChanged<String>? onPinTap;

  /// Called when the user taps the map (e.g. to place / move a pin).
  final ValueChanged<GeoPoint>? onMapTap;
  final bool showIncidentSummary;
  final double height;

  @override
  State<FieldMap> createState() => _FieldMapState();
}

class _FieldMapState extends State<FieldMap> {
  final _controller = MapController();

  @override
  void didUpdateWidget(FieldMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.fields, widget.fields)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitAll();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<LatLng> get _allPoints => [
    for (final field in widget.fields) ...[
      _latLng(field.center),
      ...field.outline.map(_latLng),
    ],
    for (final pin in widget.pins) _latLng(pin.position),
  ];

  LatLng get _fallbackCenter =>
      const LatLng(mapDefaultLatitude, mapDefaultLongitude);

  CameraFit get _cameraFit => CameraFit.coordinates(
    coordinates: _allPoints.isEmpty ? [_fallbackCenter] : _allPoints,
    padding: const EdgeInsets.all(56),
    maxZoom: 17,
  );

  void _fitAll() {
    _controller.fitCamera(_cameraFit);
  }

  void _zoomBy(double delta) {
    final camera = _controller.camera;
    _controller.move(camera.center, camera.zoom + delta);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final points = _allPoints;
    final single = points.length == 1;

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: single ? points.first : _fallbackCenter,
                  initialZoom: single ? 17 : (points.isEmpty ? 13 : 12),
                  initialCameraFit: points.length > 1 ? _cameraFit : null,
                  maxZoom: mapMaxZoom,
                  backgroundColor: _basemapFallback,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: widget.onMapTap == null
                      ? null
                      : (_, point) => widget.onMapTap!(
                          GeoPoint(
                            latitude: point.latitude,
                            longitude: point.longitude,
                          ),
                        ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: mapTileUrl,
                    subdomains: mapTileSubdomains,
                    userAgentPackageName: mapUserAgentPackageName,
                    maxNativeZoom: mapMaxZoom.toInt(),
                  ),
                  PolygonLayer(
                    polygons: [
                      for (final field in widget.fields)
                        if (field.outline.length >= 3)
                          Polygon(
                            points: field.outline.map(_latLng).toList(),
                            color: _fieldFill,
                            borderColor: _accent,
                            borderStrokeWidth: 2.5,
                          ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      for (final field in widget.fields)
                        Marker(
                          point: _latLng(field.center),
                          width: 160,
                          height: 64,
                          child: _FieldMarker(name: field.name),
                        ),
                      for (final pin in widget.pins)
                        Marker(
                          point: _latLng(pin.position),
                          width: 28,
                          height: 28,
                          alignment: Alignment.topRight,
                          child: _PinMarker(
                            resolved: pin.resolved,
                            onTap: pin.id == null || widget.onPinTap == null
                                ? null
                                : () => widget.onPinTap!(pin.id!),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.onMapTap != null && widget.fields.isEmpty)
              const Center(
                child: Icon(
                  Icons.add_location_alt,
                  size: 40,
                  color: _accent,
                  shadows: [Shadow(color: Color(0x80000000), blurRadius: 6)],
                ),
              ),
            const Positioned(left: 0, bottom: 0, child: _Attribution()),
            if (widget.onAddField != null)
              Positioned(
                top: 12,
                left: 12,
                child: _AddFieldButton(onPressed: widget.onAddField!),
              ),
            if (widget.showIncidentSummary)
              Positioned(
                top: 12,
                right: 12,
                child: _IncidentSummary(
                  pins: widget.pins,
                  textTheme: textTheme,
                ),
              ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapControl(
                    icon: Icons.add,
                    tooltip: 'Acercar',
                    onPressed: () => _zoomBy(1),
                  ),
                  _MapControl(
                    icon: Icons.remove,
                    tooltip: 'Alejar',
                    onPressed: () => _zoomBy(-1),
                  ),
                  _MapControl(
                    icon: Icons.center_focus_strong_outlined,
                    tooltip: 'Ver mis terrenos',
                    onPressed: _fitAll,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFieldButton extends StatelessWidget {
  const _AddFieldButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _accent,
      elevation: 2,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.white, size: 20),
              SizedBox(width: 6),
              Text(
                'Agregar terreno',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncidentSummary extends StatelessWidget {
  const _IncidentSummary({required this.pins, required this.textTheme});

  final List<MapPin> pins;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final open = pins.where((pin) => !pin.resolved).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _panelDecoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: _pinColor, size: 22),
          const SizedBox(width: 8),
          Text(
            open == 1 ? '1 problema' : '$open problemas',
            style: textTheme.labelLarge?.copyWith(
              color: const Color(0xFF1B1B1B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      margin: const EdgeInsets.only(top: 8),
      decoration: _panelDecoration,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF37474F)),
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xB3FFFFFF),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: const Text(
        '© $mapTileAttribution',
        style: TextStyle(color: Color(0xFF1B1B1B), fontSize: 10),
      ),
    );
  }
}

class _FieldMarker extends StatelessWidget {
  const _FieldMarker({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.location_on,
          color: _accent,
          size: 32,
          shadows: [Shadow(color: Color(0x80000000), blurRadius: 6)],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: const BoxDecoration(
            color: _panelColor,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1B1B1B),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PinMarker extends StatelessWidget {
  const _PinMarker({required this.resolved, this.onTap});

  final bool resolved;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final marker = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: resolved ? const Color(0xFF78909C) : _pinColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.priority_high, size: 16, color: Colors.white),
    );
    if (onTap == null) return marker;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(button: true, label: 'Abrir caso', child: marker),
    );
  }
}
