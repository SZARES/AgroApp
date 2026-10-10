import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'domain/models/app_user.dart';
import 'domain/models/user_role.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/home/view_models/home_view_model.dart';
import 'ui/features/home/views/home_view.dart';
import 'ui/features/login/view_models/login_view_model.dart';
import 'ui/features/login/views/login_view.dart';
import 'ui/features/staff_home/views/staff_home_view.dart';
import 'ui/features/welcome/views/welcome_view.dart';

class AgroApp extends StatelessWidget {
  const AgroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgroApp',
      theme: AppTheme.light(),
      home: const _Welcome(),
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

  void _openRoleHome(BuildContext context, AppUser user) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => switch (user.role) {
          UserRole.farmer => const _FarmerHome(),
          _ => _StaffHome(role: user.role),
        },
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LoginViewModel(authRepository: context.read()),
      builder: (context, _) => LoginView(
        viewModel: context.read<LoginViewModel>(),
        onSignedIn: (user) => _openRoleHome(context, user),
      ),
    );
  }
}

class _FarmerHome extends StatelessWidget {
  const _FarmerHome();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => HomeViewModel(
        outboxRepository: context.read(),
        syncEngine: context.read(),
      ),
      builder: (context, _) =>
          HomeView(viewModel: context.read<HomeViewModel>()),
    );
  }
}

class _StaffHome extends StatelessWidget {
  const _StaffHome({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return StaffHomeView(
      role: role,
      onSignOut: () => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const _Welcome()),
        (_) => false,
      ),
    );
  }
}
