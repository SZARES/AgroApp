import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/home_repository.dart';
import 'data/repositories/location_repository.dart';
import 'data/repositories/parcel_repository.dart';
import 'domain/models/app_user.dart';
import 'domain/models/auth_failure.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/auth/view_models/auth_view_model.dart';
import 'ui/features/auth/views/auth_gate.dart';
import 'ui/features/auth/views/sign_out_flow.dart';
import 'ui/features/console/views/console_view.dart';
import 'ui/features/home/view_models/home_view_model.dart';
import 'ui/features/home/views/home_view.dart';
import 'ui/features/login/view_models/login_view_model.dart';
import 'ui/features/parcel/view_models/add_parcel_view_model.dart';
import 'ui/features/parcel/view_models/parcel_view_model.dart';
import 'ui/features/parcel/views/parcel_view.dart';
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
            farmerBuilder: (_, user, onSignOut) =>
                _FarmerHome(user: user, onSignOut: onSignOut),
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
    final notice = _noticeFor(context.read<AuthViewModel>().restoreFailure);
    return Stack(
      children: [
        WelcomeView(
          onStart: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const _Login())),
        ),
        if (notice != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    notice,
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String? _noticeFor(AuthFailure? failure) => switch (failure) {
    AuthFailure.sessionExpired =>
      'Su sesión venció. Vuelva a entrar con su DNI o correo',
    AuthFailure.inactiveAccount =>
      'Su cuenta está desactivada. Hable con su técnico de AIDER',
    AuthFailure.noProfile =>
      'Su cuenta todavía no está lista. Hable con su técnico de AIDER',
    _ => null,
  };
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
  const _FarmerHome({required this.user, required this.onSignOut});

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final farmerId = user.farmerId ?? '';
    return MultiProvider(
      providers: [
        Provider<HomeRepository>(
          create: (context) =>
              LocalHomeRepository(store: context.read(), farmerId: farmerId),
        ),
        Provider<ParcelRepository>(
          create: (context) =>
              LocalParcelRepository(store: context.read(), farmerId: farmerId),
        ),
        ChangeNotifierProvider(
          create: (context) => HomeViewModel(
            outboxRepository: context.read(),
            homeRepository: context.read(),
            syncEngine: context.read(),
            fullName: user.fullName,
          ),
        ),
      ],
      builder: (context, _) => Stack(
        children: [
          HomeView(
            viewModel: context.read<HomeViewModel>(),
            parcelBuilder: (_) =>
                _ParcelScreen(repository: context.read<ParcelRepository>()),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                onPressed: onSignOut,
                tooltip: 'Cerrar sesión',
                constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                icon: const Icon(Icons.logout, semanticLabel: 'Cerrar sesión'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParcelScreen extends StatelessWidget {
  const _ParcelScreen({required this.repository});

  final ParcelRepository repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ParcelViewModel(repository: repository),
      builder: (context, _) => ParcelView(
        viewModel: context.read<ParcelViewModel>(),
        addParcelViewModelBuilder: () => AddParcelViewModel(
          repository: repository,
          locationRepository: context.read<LocationRepository>(),
        ),
      ),
    );
  }
}
