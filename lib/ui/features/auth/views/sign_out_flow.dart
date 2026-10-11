import 'package:flutter/material.dart';

import '../../../../domain/models/auth_failure.dart';
import '../../../../utils/result.dart';
import '../view_models/auth_view_model.dart';

/// Signs out, asking first when that would discard records not yet uploaded.
Future<void> confirmAndSignOut(
  BuildContext context,
  AuthViewModel authViewModel,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final result = await authViewModel.signOut();
  if (result is! Error<void>) return;

  final error = result.error;
  if (error is PendingDataBlocksSignOut) {
    if (!context.mounted) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hay datos sin enviar'),
        content: Text(
          error.unsentCount == 1
              ? 'Tiene 1 registro que todavía no se envió. '
                    'Si sale ahora, se va a perder.'
              : 'Tiene ${error.unsentCount} registros que todavía no se '
                    'enviaron. Si sale ahora, se van a perder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quedarme'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir y perderlos'),
          ),
        ],
      ),
    );
    if (discard == true) await authViewModel.signOut(force: true);
    return;
  }
  messenger?.showSnackBar(
    const SnackBar(
      content: Text('No pudimos cerrar la sesión. Intente de nuevo'),
    ),
  );
}
