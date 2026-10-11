import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/activity_repository.dart';
import 'data/repositories/assistance_repository.dart';
import 'data/repositories/harvest_repository.dart';
import 'data/repositories/home_repository.dart';
import 'data/repositories/incident_repository.dart';
import 'data/repositories/location_repository.dart';
import 'data/repositories/parcel_repository.dart';
import 'data/repositories/technician_repository.dart';
import 'data/services/photo_service.dart';
import 'data/sync/sync_engine.dart';
import 'domain/models/app_user.dart';
import 'domain/models/activity.dart';
import 'domain/models/assistance.dart';
import 'domain/models/auth_failure.dart';
import 'domain/models/harvest.dart';
import 'domain/models/user_role.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/core/widgets/stream_view_model.dart';
import 'ui/features/activity_log/view_models/record_activity_view_model.dart';
import 'ui/features/activity_log/views/activity_detail_view.dart';
import 'ui/features/activity_log/views/activity_log_view.dart';
import 'ui/features/activity_log/views/record_activity_view.dart';
import 'ui/features/assistance/view_models/assistance_detail_view_model.dart';
import 'ui/features/assistance/view_models/external_visit_view_model.dart';
import 'ui/features/assistance/views/assistance_detail_view.dart';
import 'ui/features/assistance/views/assistance_view.dart';
import 'ui/features/assistance/views/external_visit_view.dart';
import 'ui/features/auth/view_models/auth_view_model.dart';
import 'ui/features/harvest/view_models/record_harvest_view_model.dart';
import 'ui/features/harvest/views/harvest_view.dart';
import 'ui/features/harvest/views/record_harvest_view.dart';
import 'ui/features/auth/views/auth_gate.dart';
import 'ui/features/auth/views/sign_out_flow.dart';
import 'ui/features/console/views/console_view.dart';
import 'ui/features/home/view_models/home_view_model.dart';
import 'ui/features/home/views/home_view.dart';
import 'ui/features/incident_report/view_models/case_status_view_model.dart';
import 'ui/features/incident_report/view_models/incidents_view_model.dart';
import 'ui/features/incident_report/view_models/report_incident_view_model.dart';
import 'ui/features/incident_report/views/case_status_view.dart';
import 'ui/features/incident_report/views/incident_report_view.dart';
import 'ui/features/incident_report/views/incidents_list_view.dart';
import 'ui/features/login/view_models/login_view_model.dart';
import 'ui/features/parcel/view_models/add_parcel_view_model.dart';
import 'ui/features/parcel/view_models/parcel_view_model.dart';
import 'ui/features/parcel/views/parcel_view.dart';
import 'ui/features/login/views/login_view.dart';
import 'ui/features/technician/view_models/technician_case_view_model.dart';
import 'ui/features/technician/view_models/technician_cases_view_model.dart';
import 'ui/features/technician/views/technician_case_detail_view.dart';
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
            technicianMobileBuilder: (_, user, onSignOut) => _TechnicianScope(
              key: ValueKey(user.id),
              user: user,
              child: Builder(
                builder: (context) {
                  final repository = context.read<TechnicianRepository>();
                  return TechnicianHomeView(
                    viewModel: context.read<TechnicianCasesViewModel>(),
                    caseBuilder: (id) =>
                        _TechnicianCaseScreen(repository: repository, caseId: id),
                    onSignOut: onSignOut,
                  );
                },
              ),
            ),
            consoleBuilder: (_, user, onSignOut) {
              final console = ConsoleView(user: user, onSignOut: onSignOut);
              return user.role == UserRole.technician
                  ? _TechnicianScope(key: ValueKey(user.id), user: user, child: console)
                  : console;
            },
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
        Provider<IncidentRepository>(
          create: (context) => LocalIncidentRepository(
            store: context.read(),
            farmerId: farmerId,
            photoUrlResolver: context.read<SyncEngine>().signedPhotoUrl,
          ),
        ),
        Provider<ActivityRepository>(
          create: (context) => LocalActivityRepository(
            store: context.read(),
            farmerId: farmerId,
            userId: user.id,
          ),
        ),
        Provider<HarvestRepository>(
          create: (context) =>
              LocalHarvestRepository(store: context.read(), farmerId: farmerId),
        ),
        Provider<AssistanceRepository>(
          create: (context) => LocalAssistanceRepository(
            store: context.read(),
            farmerId: farmerId,
            userId: user.id,
            documentUrlResolver: context.read<SyncEngine>().signedDocumentUrl,
          ),
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
            activityBuilder: (_) => _ActivityScreen(
              repository: context.read<ActivityRepository>(),
            ),
            harvestBuilder: (_) =>
                _HarvestScreen(repository: context.read<HarvestRepository>()),
            assistanceBuilder: (_) => _AssistanceScreen(
              repository: context.read<AssistanceRepository>(),
              photoService: context.read<PhotoService>(),
            ),
            reportBuilder: (_) => _ReportScreen(
              repository: context.read<IncidentRepository>(),
              photoService: context.read<PhotoService>(),
            ),
            reportsBuilder: (_) =>
                _ReportsScreen(repository: context.read<IncidentRepository>()),
            caseBuilder: (id) => _CaseScreen(
              repository: context.read<IncidentRepository>(),
              incidentId: id,
            ),
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

class _ActivityScreen extends StatelessWidget {
  const _ActivityScreen({required this.repository});

  final ActivityRepository repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StreamViewModel<List<ActivitySummary>>(
        stream: repository.watchActivities(),
        initial: const [],
      ),
      builder: (context, _) => ActivityLogView(
        viewModel: context.read<StreamViewModel<List<ActivitySummary>>>(),
        recordBuilder: (_) => ChangeNotifierProvider(
          create: (_) => RecordActivityViewModel(repository: repository),
          builder: (context, _) =>
              RecordActivityView(viewModel: context.read()),
        ),
        detailBuilder: (id) => ChangeNotifierProvider(
          create: (_) => StreamViewModel<ActivityDetail?>(
            stream: repository.watchActivity(id),
            initial: null,
          ),
          builder: (context, _) => ActivityDetailView(
            viewModel: context.read<StreamViewModel<ActivityDetail?>>(),
          ),
        ),
      ),
    );
  }
}

class _HarvestScreen extends StatelessWidget {
  const _HarvestScreen({required this.repository});

  final HarvestRepository repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StreamViewModel<List<HarvestSummary>>(
        stream: repository.watchHarvests(),
        initial: const [],
      ),
      builder: (context, _) => HarvestView(
        viewModel: context.read<StreamViewModel<List<HarvestSummary>>>(),
        recordBuilder: (_) => ChangeNotifierProvider(
          create: (_) => RecordHarvestViewModel(repository: repository),
          builder: (context, _) =>
              RecordHarvestView(viewModel: context.read()),
        ),
      ),
    );
  }
}

class _AssistanceScreen extends StatelessWidget {
  const _AssistanceScreen({
    required this.repository,
    required this.photoService,
  });

  final AssistanceRepository repository;
  final PhotoService photoService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StreamViewModel<List<AssistanceSummary>>(
        stream: repository.watchAssistances(),
        initial: const [],
      ),
      builder: (context, _) => AssistanceView(
        viewModel: context.read<StreamViewModel<List<AssistanceSummary>>>(),
        detailBuilder: (id) => ChangeNotifierProvider(
          create: (_) => AssistanceDetailViewModel(
            repository: repository,
            assistanceId: id,
          ),
          builder: (context, _) =>
              AssistanceDetailView(viewModel: context.read()),
        ),
        externalVisitBuilder: (_) => ChangeNotifierProvider(
          create: (_) => ExternalVisitViewModel(
            repository: repository,
            photoService: photoService,
          ),
          builder: (context, _) =>
              ExternalVisitView(viewModel: context.read()),
        ),
      ),
    );
  }
}

class _ReportScreen extends StatelessWidget {
  const _ReportScreen({required this.repository, required this.photoService});

  final IncidentRepository repository;
  final PhotoService photoService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReportIncidentViewModel(
        repository: repository,
        photoService: photoService,
      ),
      builder: (context, _) => IncidentReportView(
        viewModel: context.read<ReportIncidentViewModel>(),
        caseBuilder: (id) =>
            _CaseScreen(repository: repository, incidentId: id),
      ),
    );
  }
}

class _ReportsScreen extends StatelessWidget {
  const _ReportsScreen({required this.repository});

  final IncidentRepository repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => IncidentsViewModel(repository: repository),
      builder: (context, _) => IncidentsListView(
        viewModel: context.read<IncidentsViewModel>(),
        caseBuilder: (id) =>
            _CaseScreen(repository: repository, incidentId: id),
      ),
    );
  }
}

class _CaseScreen extends StatelessWidget {
  const _CaseScreen({required this.repository, required this.incidentId});

  final IncidentRepository repository;
  final String incidentId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          CaseStatusViewModel(repository: repository, incidentId: incidentId),
      builder: (context, _) =>
          CaseStatusView(viewModel: context.read<CaseStatusViewModel>()),
    );
  }
}

/// Technician data for the signed-in technician, shared by the phone screens
/// and the web console.
class _TechnicianScope extends StatelessWidget {
  const _TechnicianScope({super.key, required this.user, required this.child});

  final AppUser user;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TechnicianRepository>(
          create: (context) => LocalTechnicianRepository(
            store: context.read(),
            technicianId: user.id,
            photoUrlResolver: context.read<SyncEngine>().signedPhotoUrl,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => TechnicianCasesViewModel(
            repository: context.read<TechnicianRepository>(),
          ),
        ),
      ],
      child: child,
    );
  }
}

class _TechnicianCaseScreen extends StatelessWidget {
  const _TechnicianCaseScreen({required this.repository, required this.caseId});

  final TechnicianRepository repository;
  final String caseId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          TechnicianCaseViewModel(repository: repository, caseId: caseId),
      builder: (context, _) => TechnicianCaseDetailView(
        viewModel: context.read<TechnicianCaseViewModel>(),
      ),
    );
  }
}
