import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'domain/models/app_user.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/auth/view_models/auth_view_model.dart';
import 'ui/features/auth/views/auth_gate.dart';
import 'ui/features/auth/views/sign_out_flow.dart';
import 'ui/features/console/views/console_view.dart';
import 'ui/features/home/view_models/home_view_model.dart';
import 'ui/features/home/views/home_view.dart';
import 'ui/features/login/view_models/login_view_model.dart';
import 'ui/features/login/views/login_view.dart';
import 'ui/features/technician/views/technician_home_view.dart';
import 'ui/features/welcome/views/welcome_view.dart';

class AgroApp extends StatelessWidget {
  const AgroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgroApp',
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) {
          final auth = context.read<AuthViewModel>();
          return AuthGate(
            viewModel: auth,
            onSignOut: () => confirmAndSignOut(context, auth),
            signedOutBuilder: (_) => const _Welcome(),
            farmerBuilder: (_, _, onSignOut) =>
                _FarmerHome(onSignOut: onSignOut),
            technicianMobileBuilder: (_, _, onSignOut) =>
                TechnicianHomeView(onSignOut: onSignOut),
            consoleBuilder: (_, user, onSignOut) =>
                ConsoleView(user: user, onSignOut: onSignOut),
          );
        },
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    return WelcomeView(
      onStart: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const _Login())),
    );
  }
}

class _Login extends StatelessWidget {
  const _Login();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LoginViewModel(authViewModel: context.read()),
      builder: (context, _) => LoginView(
        viewModel: context.read<LoginViewModel>(),
        // The AuthGate swaps the home screen and pops this route itself.
        onSignedIn: (AppUser _) {},
      ),
    );
  }
}

class _FarmerHome extends StatelessWidget {
  const _FarmerHome({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => HomeViewModel(
        outboxRepository: context.read(),
        syncEngine: context.read(),
      ),
      builder: (context, _) => Stack(
        children: [
          HomeView(viewModel: context.read<HomeViewModel>()),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                onPressed: onSignOut,
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
