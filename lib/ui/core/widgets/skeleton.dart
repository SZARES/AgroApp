import 'package:flutter/material.dart';

/// Pulsing placeholder shown while content loads.
///
/// Wrap skeleton shapes ([SkeletonBox], [SkeletonLine], [SkeletonCard]) in a
/// [Skeleton]: it owns the single pulse animation, announces "Cargando" to
/// screen readers (hiding the shapes) and stays still when the platform asks
/// for reduced motion. [SkeletonList] already includes it.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  /// Current pulse value (0..1) of the nearest [Skeleton]; 0 without one.
  static Animation<double>? _of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_SkeletonPulse>()
      ?.animation;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      container: true,
      child: ExcludeSemantics(
        child: _SkeletonPulse(animation: _controller, child: widget.child),
      ),
    );
  }
}

class _SkeletonPulse extends InheritedWidget {
  const _SkeletonPulse({required this.animation, required super.child});

  final Animation<double> animation;

  // The animation notifies its own listeners; the inherited value is stable.
  @override
  bool updateShouldNotify(_SkeletonPulse oldWidget) =>
      animation != oldWidget.animation;
}

/// A rounded grey block that pulses inside a [Skeleton].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double? height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pulse = Skeleton._of(context);
    final base = scheme.surfaceContainerHighest;
    final light = scheme.surfaceContainerHigh;

    Widget block(double t) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Color.lerp(base, light, t),
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(radius),
      ),
    );

    if (pulse == null) return block(0);
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, _) => block(pulse.value),
    );
  }
}

/// A text-like bar; [widthFactor] is the share of the available width.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.widthFactor = 1, this.height = 14});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: SkeletonBox(height: height, radius: 6),
    );
  }
}

/// A card-shaped placeholder: a title bar, a subtitle bar and a short chip.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height});

  /// Fixed height; by default the card sizes itself to its lines.
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: height,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SkeletonLine(widthFactor: 0.6, height: 16),
              SizedBox(height: 10),
              SkeletonLine(widthFactor: 0.9),
              SizedBox(height: 10),
              SkeletonLine(widthFactor: 0.3, height: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card-shaped rows that stand in for a list while it loads.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.padding});

  final int count;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    // A scroll view that never scrolls: it clips when the parent is bounded
    // and shrinks to its rows inside another scrollable.
    return Skeleton(
      child: SingleChildScrollView(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              const SkeletonCard(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Stand-in for a detail screen: a header, a few lines and a block.
class SkeletonDetail extends StatelessWidget {
  const SkeletonDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonLine(widthFactor: 0.7, height: 28),
            SizedBox(height: 12),
            SkeletonLine(widthFactor: 0.5),
            SizedBox(height: 20),
            SkeletonLine(widthFactor: 0.35, height: 28),
            SizedBox(height: 24),
            SkeletonBox(height: 120),
            SizedBox(height: 16),
            SkeletonBox(height: 72),
            SizedBox(height: 16),
            SkeletonBox(height: 72),
          ],
        ),
      ),
    );
  }
}
