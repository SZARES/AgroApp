import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/app_user.dart';
import '../view_models/login_view_model.dart';

class LoginView extends StatefulWidget {
  const LoginView({
    super.key,
    required this.viewModel,
    required this.onSignedIn,
  });

  final LoginViewModel viewModel;
  final ValueChanged<AppUser> onSignedIn;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _dniController = TextEditingController();

  @override
  void dispose() {
    _dniController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = await widget.viewModel.signIn(_dniController.text);
    if (user != null && mounted) widget.onSignedIn(user);
  }

  String? _errorText(LoginError? error) {
    return switch (error) {
      null => null,
      LoginError.invalidFormat => 'El DNI debe tener 8 números',
      LoginError.unknownDni => 'Este DNI no está registrado',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListenableBuilder(
                listenable: widget.viewModel,
                builder: (context, _) {
                  final viewModel = widget.viewModel;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.eco,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ingrese su DNI',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _dniController,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        textAlign: TextAlign.center,
                        maxLength: LoginViewModel.dniLength,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(fontSize: 32, letterSpacing: 4),
                        decoration: InputDecoration(
                          labelText: 'DNI',
                          border: const OutlineInputBorder(),
                          errorText: _errorText(viewModel.error),
                          errorStyle: const TextStyle(fontSize: 16),
                        ),
                        onChanged: (_) => viewModel.clearError(),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: viewModel.isLoading ? null : _submit,
                        child: const Text('Ingresar'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
