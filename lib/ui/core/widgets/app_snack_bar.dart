import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shows a floating snackbar; on Android it appears near the top so it is
/// easier to notice above the system nav bar.
void showAppSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  final theme = Theme.of(context);
  final snackTheme = theme.snackBarTheme;
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final height = MediaQuery.sizeOf(context).height;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: snackTheme.backgroundColor,
        margin: isAndroid
            ? EdgeInsets.only(bottom: height - 140, left: 16, right: 16)
            : const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
}
