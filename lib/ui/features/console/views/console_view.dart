import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/repositories/supervisor_repository.dart';
import '../../../../data/repositories/technician_repository.dart';
import '../../../../domain/models/app_user.dart';
import '../../../../domain/models/user_role.dart';
import '../../../core/widgets/aider_shell.dart';
import '../../../core/widgets/three_panel_scaffold.dart';
import '../../admin/views/admin_view.dart';
import '../../supervisor/views/supervisor_dashboard_view.dart';
import '../../technician/view_models/technician_case_view_model.dart';
import '../../technician/view_models/technician_cases_view_model.dart';
import '../../technician/views/technician_workspace.dart';
import '../console_modules.dart';

/// The AIDER web console for technicians, supervisors and admins.
///
/// Modules whose data is connected show it; the rest are honest placeholders.
class ConsoleView extends StatefulWidget {
  const ConsoleView({super.key, required this.user, required this.onSignOut});

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<ConsoleView> createState() => _ConsoleViewState();
}

class _ConsoleViewState extends State<ConsoleView> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final List<AiderNavItem> _modules = ConsoleModules.forRole(
    widget.user.role,
  );
  late String _selectedId = _modules.first.id;

  AiderNavItem get _selected =>
      _modules.firstWhere((module) => module.id == _selectedId);

  void _select(String id) {
    setState(() => _selectedId = id);
    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) scaffold.closeDrawer();
  }

  /// The admin repository when the app provides one (tests may not).
  AdminRepository? _adminRepository(BuildContext context) {
    try {
      return context.read<AdminRepository>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// The technician's alert inbox when the app provides one (tests may not).
  TechnicianCasesViewModel? _technicianCases(BuildContext context) {
    if (widget.user.role != UserRole.technician) return null;
    try {
      return context.read<TechnicianCasesViewModel>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// The supervisor's dashboard repository (supervisors only; tests may not).
  SupervisorRepository? _supervisorRepository(BuildContext context) {
    if (widget.user.role != UserRole.supervisor) return null;
    try {
      return context.read<SupervisorRepository>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Widget _scaffold(
    AiderNavItem module,
    Widget listPanel,
    Widget mainArea, {
    int alertCount = 0,
  }) {
    return ThreePanelScaffold(
      scaffoldKey: _scaffoldKey,
      title: Text(module.label),
      sidebar: AiderSidebar(
        items: _modules,
        selectedId: _selectedId,
        onSelect: _select,
        userName: widget.user.fullName,
        onSignOut: widget.onSignOut,
        alertCount: alertCount,
      ),
      listPanel: listPanel,
      mainArea: mainArea,
    );
  }

  @override
  Widget build(BuildContext context) {
    final module = _selected;
    if (module.id == ConsoleModules.admin.id) {
      final repository = _adminRepository(context);
      if (repository != null) {
        return AdminView(
          user: widget.user,
          repository: repository,
          panelsBuilder: (listPanel, mainArea) =>
              _scaffold(module, listPanel, mainArea),
        );
      }
    }
    final cases = _technicianCases(context);
    if (cases != null &&
        (module.id == ConsoleModules.home.id ||
            module.id == ConsoleModules.alerts.id)) {
      final repository = context.read<TechnicianRepository>();
      return TechnicianWorkspace(
        viewModel: cases,
        caseViewModelBuilder: (id) =>
            TechnicianCaseViewModel(repository: repository, caseId: id),
        panelsBuilder: (listPanel, mainArea) => _scaffold(
          module,
          listPanel,
          mainArea,
          alertCount: cases.openCount,
        ),
      );
    }
    if (module.id == ConsoleModules.home.id) {
      final supervisorRepository = _supervisorRepository(context);
      if (supervisorRepository != null) {
        return SupervisorDashboardView(
          repository: supervisorRepository,
          panelsBuilder: (listPanel, mainArea) =>
              _scaffold(module, listPanel, mainArea),
        );
      }
    }
    return _scaffold(
      module,
      AiderListPanel(
        title: module.label,
        items: const [],
        selectedId: null,
        onSelect: (_) {},
      ),
      AiderMainArea(child: ModulePlaceholder(item: module)),
    );
  }
}
