import 'package:flutter/material.dart';

import '../../../../../domain/models/admin/create_user_request.dart';

/// Asks for a new password (at least 8 characters). Returns null on cancel.
/// Nothing sensitive is echoed back after confirming.
Future<String?> askNewPassword(BuildContext context, String personName) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PasswordDialog(personName: personName),
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.personName});

  final String personName;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _visible = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_controller.text.length < CreateUserRequest.minPasswordLength) {
      setState(() {
        _error =
            'Use al menos ${CreateUserRequest.minPasswordLength} caracteres';
      });
      return;
    }
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nueva contraseña para ${widget.personName}.'),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('reset_password_field'),
            controller: _controller,
            obscureText: !_visible,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              errorText: _error,
              suffixIcon: IconButton(
                tooltip: _visible ? 'Ocultar' : 'Mostrar',
                icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _visible = !_visible),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('reset_password_confirm'),
          onPressed: _confirm,
          child: const Text('Cambiar'),
        ),
      ],
    );
  }
}

/// Yes/no confirmation; true only when the person confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('confirm_action'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
