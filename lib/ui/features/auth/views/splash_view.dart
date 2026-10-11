import 'package:flutter/material.dart';

/// Branded screen shown while the saved session is being checked.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco, size: 96, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              'AgroApp',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 44,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
