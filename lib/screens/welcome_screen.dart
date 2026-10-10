import 'package:flutter/material.dart';

const _brandGreen = Color(0xFF2E9E3F);
const _skyTint = Color(0xFFEAF4FB);

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.onStart});

  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: _skyTint,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The photo starts below the top so the farmer sits in the lower
          // half, leaving clear sky for the branding.
          Positioned(
            top: height * 0.2,
            left: 0,
            right: 0,
            bottom: 0,
            child: Image.asset(
              'assets/images/welcome_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.22, 0.5],
                colors: [_skyTint, _skyTint, Color(0x00EAF4FB)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(height: height * 0.06),
                  const Icon(Icons.eco, size: 88, color: _brandGreen),
                  const SizedBox(height: 4),
                  const Text(
                    'AgroApp',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B1B1B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tu parcela, nuestro compromiso',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: FilledButton(
                      onPressed: onStart ?? () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: _brandGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Comenzar'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
