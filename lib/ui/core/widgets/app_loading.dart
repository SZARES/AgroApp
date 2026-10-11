import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated leaf + ring used inside loading surfaces.
class AppLoadingIndicator extends StatefulWidget {
  const AppLoadingIndicator({super.key, this.size = 72});

  final double size;

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = widget.size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final pulse = 0.92 + 0.08 * math.sin(t * math.pi * 2);
        final ringAngle = t * math.pi * 2;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: ringAngle,
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _RingPainter(
                    color: scheme.primary,
                    accent: scheme.secondary,
                  ),
                ),
              ),
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: size * 0.52,
                  height: size * 0.52,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.outline, width: 1.5),
                  ),
                  child: Icon(
                    Icons.eco,
                    size: size * 0.3,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.color, required this.accent});

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final track = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = accent;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.35,
      false,
      arc,
    );
    final tip = Offset(
      center.dx + radius * math.cos(-math.pi / 2 + math.pi * 1.35),
      center.dy + radius * math.sin(-math.pi / 2 + math.pi * 1.35),
    );
    canvas.drawCircle(tip, 4.5, dot);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accent != accent;
}

/// Card content for loading modals and full-screen placeholders.
class AppLoadingCard extends StatelessWidget {
  const AppLoadingCard({
    super.key,
    this.message = 'Cargando…',
    this.compact = false,
  });

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = compact ? 24.0 : 32.0;

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 10,
      shadowColor: const Color(0x88000000),
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: pad + 8, vertical: pad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLoadingIndicator(size: compact ? 64 : 80),
            SizedBox(height: compact ? 16 : 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dimmed barrier + animated card. Blocks taps while [visible].
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    required this.visible,
    this.message = 'Cargando…',
    required this.child,
  });

  final bool visible;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: AbsorbPointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, value, overlay) => Opacity(
                  opacity: value,
                  child: overlay,
                ),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.88, end: 1),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, card) =>
                          Transform.scale(scale: scale, child: card),
                      child: AppLoadingCard(message: message),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Modal dialog that cannot be dismissed by the user.
Future<void> showAppLoading(
  BuildContext context, {
  String message = 'Cargando…',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (context) => PopScope(
      canPop: false,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.88, end: 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: AppLoadingCard(message: message),
        ),
      ),
    ),
  );
}

/// Closes the dialog opened by [showAppLoading].
void hideAppLoading(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (navigator.canPop()) navigator.pop();
}
