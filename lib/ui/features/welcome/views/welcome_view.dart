import 'package:flutter/material.dart';

/// First screen of the app: brand, tagline and a single entry action.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key, required this.onStart});

  final VoidCallback onStart;

  static const mobileBackground = 'assets/bgImagenMobil.jpeg';
  static const webBackground = 'assets/bgImagenWeb.jpeg';
  static const wideBreakpoint = 720.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide =
              constraints.maxWidth >= wideBreakpoint &&
              constraints.maxWidth > constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              _AnimatedBackground(
                asset: isWide ? webBackground : mobileBackground,
                alignment: isWide ? Alignment.centerLeft : Alignment.center,
              ),
              if (isWide)
                _WideLayout(onStart: onStart)
              else
                _NarrowLayout(onStart: onStart),
            ],
          );
        },
      ),
    );
  }
}

/// Slow Ken Burns drift on the static photo (no GIF asset available).
class _AnimatedBackground extends StatefulWidget {
  const _AnimatedBackground({required this.asset, required this.alignment});

  final String asset;
  final Alignment alignment;

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 1.08)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          alignment: widget.alignment,
          child: child,
        );
      },
      child: Image.asset(
        widget.asset,
        fit: BoxFit.cover,
        alignment: widget.alignment,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Color(0xCC000000),
                Color(0x66000000),
                Color(0x00000000),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                const _Brand(onDark: true),
                const Spacer(),
                _StartButton(onStart: onStart),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xE6FFFFFF),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _Brand(onDark: false),
                    const SizedBox(height: 40),
                    _StartButton(onStart: onStart),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.onDark});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final titleColor = onDark ? Colors.white : const Color(0xFF1B1B1B);
    final taglineColor =
        onDark ? Colors.white.withValues(alpha: 0.92) : const Color(0xFF1B1B1B);
    final iconColor = onDark ? Colors.white : colors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.eco, size: 88, color: iconColor),
        const SizedBox(height: 4),
        Text(
          'AgroApp',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: titleColor,
            height: 1.1,
            shadows: onDark
                ? const [
                    Shadow(
                      color: Color(0x99000000),
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tu parcela, nuestro compromiso',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: taglineColor,
            shadows: onDark
                ? const [
                    Shadow(
                      color: Color(0x80000000),
                      blurRadius: 8,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}

class _StartButton extends StatefulWidget {
  const _StartButton({required this.onStart});

  final VoidCallback onStart;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 1.035)
      .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ScaleTransition(
      scale: _scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: widget.onStart,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            shape: const StadiumBorder(),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Comenzar'),
        ),
      ),
    );
  }
}
