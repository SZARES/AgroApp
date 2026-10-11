import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../domain/models/app_user.dart';
import '../../../../domain/models/user_role.dart';
import '../view_models/auth_view_model.dart';
import 'splash_view.dart';

typedef UserWidgetBuilder =
    Widget Function(BuildContext context, AppUser user, VoidCallback onSignOut);

/// Chooses what to show from the session state and the user's role.
///
/// * unknown: splash while the saved session is checked;
/// * signed out: [signedOutBuilder];
/// * farmer: [farmerBuilder] in a centered column (max [farmerMaxWidth]);
/// * technician: [technicianMobileBuilder] on a phone, [consoleBuilder] on the
///   web or a wide window;
/// * supervisor/admin: [consoleBuilder]; a phone first gets a friendly hint
///   to use a computer, with a way to continue anyway.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.viewModel,
    required this.signedOutBuilder,
    required this.farmerBuilder,
    required this.technicianMobileBuilder,
    required this.consoleBuilder,
    required this.onSignOut,
    this.forceWebLayout,
  });

  static const wideBreakpoint = 900.0;
  static const phoneBreakpoint = 600.0;
  static const farmerMaxWidth = 600.0;

  final AuthViewModel viewModel;
  final WidgetBuilder signedOutBuilder;
  final UserWidgetBuilder farmerBuilder;
  final UserWidgetBuilder technicianMobileBuilder;
  final UserWidgetBuilder consoleBuilder;
  final VoidCallback onSignOut;

  /// Overrides `kIsWeb` (tests).
  final bool? forceWebLayout;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _continueOnPhone = false;
  Object? _lastIdentity;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onSessionChanged);
  }

  @override
  void didUpdateWidget(AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_onSessionChanged);
      widget.viewModel.addListener(_onSessionChanged);
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// Drops any screen pushed over the previous session (case details, login)
  /// whenever who is signed in changes.
  void _onSessionChanged() {
    final identity = widget.viewModel.user?.id;
    if (identity == _lastIdentity) return;
    _lastIdentity = identity;
    _continueOnPhone = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        return switch (widget.viewModel.state) {
          AuthUnknown() => const SplashView(),
          AuthSignedOut() => widget.signedOutBuilder(context),
          AuthSignedIn(:final user) => _homeFor(context, user),
        };
      },
    );
  }

  Widget _homeFor(BuildContext context, AppUser user) {
    final width = MediaQuery.sizeOf(context).width;
    final isWeb = widget.forceWebLayout ?? kIsWeb;
    final isWide = isWeb || width >= AuthGate.wideBreakpoint;

    switch (user.role) {
      case UserRole.farmer:
        return _CenteredColumn(
          child: widget.farmerBuilder(context, user, widget.onSignOut),
        );
      case UserRole.technician:
        return isWide
            ? widget.consoleBuilder(context, user, widget.onSignOut)
            : widget.technicianMobileBuilder(context, user, widget.onSignOut);
      case UserRole.supervisor:
      case UserRole.admin:
        final isPhone = !isWeb && width < AuthGate.phoneBreakpoint;
        if (isPhone && !_continueOnPhone) {
          return DesktopHintView(
            onContinue: () => setState(() => _continueOnPhone = true),
            onSignOut: widget.onSignOut,
          );
        }
        return widget.consoleBuilder(context, user, widget.onSignOut);
    }
  }
}

class _CenteredColumn extends StatelessWidget {
  const _CenteredColumn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AuthGate.farmerMaxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Friendly note for supervisors/admins on a phone; never blocks them.
class DesktopHintView extends StatelessWidget {
  const DesktopHintView({
    super.key,
    required this.onContinue,
    required this.onSignOut,
  });

  final VoidCallback onContinue;
  final VoidCallback onSignOut;

  static const message = 'Use la web de AIDER en una computadora';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.desktop_windows_outlined,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Su panel se ve mejor en una pantalla grande, '
                    'pero también puede seguir desde aquí.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: onContinue,
                    child: const Text('Continuar aquí'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
