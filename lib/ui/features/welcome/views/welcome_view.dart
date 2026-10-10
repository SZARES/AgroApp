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
              Image.asset(
                isWide ? webBackground : mobileBackground,
                fit: BoxFit.cover,
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

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Lightens the sky so the brand stays readable over the photo.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Color(0xB3FFFFFF), Color(0x00FFFFFF)],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                const _Brand(),
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
              ),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _Brand(),
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
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.eco, size: 88, color: colors.primary),
        const SizedBox(height: 4),
        const Text(
          'AgroApp',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B1B1B),
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tu parcela, nuestro compromiso',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B1B1B),
          ),
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onStart,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      child: const Text('Comenzar'),
    );
  }
}
