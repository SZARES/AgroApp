import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _forest = Color(0xFF0A2417);
  static const _surface = Color(0xFF123423);
  static const _surfaceHigh = Color(0xFF1A4430);
  static const _lime = Color(0xFF8BD450);
  static const _onLime = Color(0xFF0A2417);
  static const _accent = Color(0xFFF0701E);
  static const _outline = Color(0xFF2C5A44);

  static const _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(24)),
    side: BorderSide(color: _outline),
  );
  static const _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(20)),
  );
  static const _buttonText = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );
  static const _textSizes = TextTheme(
    headlineMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
    titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 20),
    bodyMedium: TextStyle(fontSize: 18),
  );

  /// Deep green surfaces with a lime highlight and an orange call to action.
  /// Large text and tap targets for small screens and older users.
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _lime,
          brightness: Brightness.dark,
        ).copyWith(
          primary: _lime,
          onPrimary: _onLime,
          primaryContainer: _surfaceHigh,
          onPrimaryContainer: Colors.white,
          secondary: _accent,
          onSecondary: Colors.white,
          surface: _forest,
          onSurface: Colors.white,
          onSurfaceVariant: const Color(0xFFB9D3C2),
          surfaceContainerLowest: _forest,
          surfaceContainerLow: _surface,
          surfaceContainer: _surface,
          surfaceContainerHigh: _surface,
          surfaceContainerHighest: _surfaceHigh,
          outline: _outline,
          outlineVariant: _outline,
        );
    final base = ThemeData(colorScheme: scheme, brightness: Brightness.dark);

    return base.copyWith(
      scaffoldBackgroundColor: _forest,
      textTheme: base.textTheme
          .merge(_textSizes)
          .apply(bodyColor: Colors.white, displayColor: Colors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: _forest,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: _surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: _cardShape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(76),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: _buttonText,
          shape: _buttonShape,
          elevation: 4,
          shadowColor: const Color(0x66000000),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _lime,
          side: const BorderSide(color: _lime, width: 1.5),
          minimumSize: const Size.fromHeight(64),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: _buttonText,
          shape: _buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _lime,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _lime, width: 2),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Lighter green so floating toasts stand out on the dark forest UI.
        backgroundColor: Color(0xFF3D7A54),
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: Colors.white,
        closeIconColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}
