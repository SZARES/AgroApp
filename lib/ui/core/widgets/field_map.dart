import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A field outline in map space. Every point is normalized to 0..1 on both axes.
class MapFieldShape {
  const MapFieldShape({required this.name, required this.points});

  final String name;
  final List<Offset> points;
}

/// An incident pin in map space. [position] is normalized to 0..1 on both axes.
class MapPin {
  const MapPin({required this.position, this.resolved = false});

  final Offset position;

  /// Resolved incidents are drawn muted so open ones stand out.
  final bool resolved;
}

const _accent = Color(0xFFF0701E);
const _fieldFill = Color(0x66F5B73B);
const _pinColor = Color(0xFFE53935);
const _panelColor = Color(0xEBFFFFFF);

const _panelDecoration = BoxDecoration(
  color: _panelColor,
  borderRadius: BorderRadius.all(Radius.circular(16)),
  boxShadow: [
    BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
  ],
);

/// Satellite-style map section with field outlines and incident pins.
///
/// The basemap is drawn in code so it works offline. Zoom and layer controls
/// are visual only until a map engine is added.
class FieldMap extends StatelessWidget {
  const FieldMap({
    super.key,
    required this.fields,
    required this.pins,
    this.onAddField,
    this.height = 360,
  });

  final List<MapFieldShape> fields;
  final List<MapPin> pins;
  final VoidCallback? onAddField;
  final double height;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _BasemapPainter()),
            ),
            Positioned.fill(child: CustomPaint(painter: _FieldsPainter(fields))),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    for (final pin in pins)
                      Positioned(
                        left: pin.position.dx * constraints.maxWidth - 14,
                        top: pin.position.dy * constraints.maxHeight - 14,
                        child: _PinMarker(resolved: pin.resolved),
                      ),
                  ],
                ),
              ),
            ),
            if (onAddField != null)
              Positioned(
                top: 12,
                left: 12,
                child: _AddFieldButton(onPressed: onAddField!),
              ),
            Positioned(
              top: 12,
              right: 12,
              child: _IncidentSummary(pins: pins, textTheme: textTheme),
            ),
            const Positioned(right: 12, bottom: 12, child: _MapControls()),
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
                'Agregar campo',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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

class _MapControls extends StatelessWidget {
  const _MapControls();

  static const _icons = [
    Icons.add,
    Icons.remove,
    Icons.sync,
    Icons.layers_outlined,
    Icons.my_location,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final icon in _icons)
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(top: 8),
            decoration: _panelDecoration,
            child: Icon(icon, color: const Color(0xFF37474F)),
          ),
      ],
    );
  }
}

class _PinMarker extends StatelessWidget {
  const _PinMarker({required this.resolved});

  final bool resolved;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: resolved ? const Color(0xFF78909C) : _pinColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x4D000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(Icons.priority_high, size: 16, color: Colors.white),
    );
  }
}

class _BasemapPainter extends CustomPainter {
  const _BasemapPainter();

  static const _tones = [
    Color(0xFF3F5E2E),
    Color(0xFF4A6B36),
    Color(0xFF6B8A4C),
    Color(0xFF7C9A58),
    Color(0xFF8DA66A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _tones[1]);

    // Seeded so the basemap looks the same on every repaint.
    final random = math.Random(42);
    for (var i = 0; i < 140; i++) {
      final paint = Paint()
        ..color = _tones[random.nextInt(_tones.length)].withValues(alpha: 0.8);
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final width = size.width * (0.05 + random.nextDouble() * 0.12);
      final height = size.height * (0.02 + random.nextDouble() * 0.05);
      canvas.drawRect(
        Rect.fromCenter(center: center, width: width, height: height),
        paint,
      );
    }

    final road = Path()
      ..moveTo(0, size.height * 0.35)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.45,
        size.width * 0.55,
        size.height * 0.1,
      )
      ..lineTo(size.width, size.height * 0.05);
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xB3D9CFB8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _BasemapPainter oldDelegate) => false;
}

class _FieldsPainter extends CustomPainter {
  const _FieldsPainter(this.fields);

  final List<MapFieldShape> fields;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = _fieldFill;
    final stroke = Paint()
      ..color = _accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    for (final field in fields) {
      final path = Path();
      for (var i = 0; i < field.points.length; i++) {
        final point = Offset(
          field.points[i].dx * size.width,
          field.points[i].dy * size.height,
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _FieldsPainter oldDelegate) =>
      oldDelegate.fields != fields;
}
