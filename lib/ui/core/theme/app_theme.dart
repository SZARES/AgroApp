import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF2E7D32);
  static const _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );
  static const _buttonText = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  static const _textSizes = TextTheme(
    headlineMedium: TextStyle(fontSize: 32),
    titleLarge: TextStyle(fontSize: 24),
    titleMedium: TextStyle(fontSize: 20),
    bodyLarge: TextStyle(fontSize: 20),
    bodyMedium: TextStyle(fontSize: 18),
  );

  /// Large text and tap targets for small screens and older users.
  static ThemeData light() {
    final base = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _seed));
    return base.copyWith(
      textTheme: base.textTheme.merge(_textSizes),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(76),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: _buttonText,
          shape: _buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(64),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: _buttonText,
          shape: _buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
