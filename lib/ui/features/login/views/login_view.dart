import 'package:flutter/material.dart';

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

  /// Plain-language message for each failure; shown under the form.
  ///
  /// [dni] tells whether the person signed in with a DNI, which changes the
  /// wording of wrong-credentials.
  static String messageFor(LoginError error, {bool dni = false}) {
    return switch (error) {
      LoginError.invalidEmail => 'Escriba un correo válido',
      LoginError.invalidDni => 'El DNI debe tener 8 números',
      LoginError.missingPassword => 'Escriba su contraseña',
      LoginError.invalidCredentials =>
        dni
            ? 'DNI o contraseña incorrecta'
            : 'DNI/correo o contraseña incorrectos',
      LoginError.inactiveAccount =>
        'Su cuenta está desactivada. Hable con su técnico de AIDER',
      LoginError.noProfile =>
        'Su cuenta todavía no está lista. Hable con su técnico de AIDER',
      LoginError.offline =>
        'No hay internet. Para entrar por primera vez en este equipo '
            'necesita conexión',
      LoginError.unknown => 'No pudimos entrar. Intente de nuevo en un momento',
    };
  }

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = await widget.viewModel.signIn(
      _emailController.text,
      _passwordController.text,
    );
    if (user != null && mounted) widget.onSignedIn(user);
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
                  final error = viewModel.error;
                  final emailError =
                      error == LoginError.invalidEmail ||
                      error == LoginError.invalidDni;
                  final passwordError = error == LoginError.missingPassword;
                  final bannerError =
                      error != null && !emailError && !passwordError;
                  return AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.eco,
                          size: 72,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Entre a su cuenta',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          autofocus: true,
                          enabled: !viewModel.isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: const TextStyle(fontSize: 22),
                          decoration: InputDecoration(
                            labelText: 'DNI o correo',
                            helperText:
                                'Agricultores: su DNI de 8 números. '
                                'Técnicos y equipo AIDER: su correo.',
                            helperMaxLines: 3,
                            helperStyle: const TextStyle(fontSize: 16),
                            prefixIcon: const Icon(Icons.person_outline),
                            errorText: emailError
                                ? LoginView.messageFor(error!)
                                : null,
                            errorMaxLines: 3,
                            errorStyle: const TextStyle(fontSize: 16),
                          ),
                          onChanged: (_) => viewModel.clearError(),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          enabled: !viewModel.isLoading,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          style: const TextStyle(fontSize: 22),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            errorText: passwordError
                                ? LoginView.messageFor(error!)
                                : null,
                            errorStyle: const TextStyle(fontSize: 16),
                          ),
                          onChanged: (_) => viewModel.clearError(),
                          onSubmitted: (_) => _submit(),
                        ),
                        if (bannerError) ...[
                          const SizedBox(height: 16),
                          _ErrorBanner(
                            message: LoginView.messageFor(
                              error,
                              dni: viewModel.lastWasDni,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: viewModel.isLoading ? null : _submit,
                          child: viewModel.isLoading
                              ? const SizedBox.square(
                                  dimension: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text('Entrar'),
                        ),
                      ],
                    ),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 18,
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
