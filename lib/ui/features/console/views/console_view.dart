import 'package:flutter/material.dart';

import '../../../../domain/models/app_user.dart';
import '../../../core/widgets/aider_shell.dart';
import '../../../core/widgets/three_panel_scaffold.dart';
import '../console_modules.dart';

/// The AIDER web console for technicians, supervisors and admins.
///
/// Every module is an honest placeholder until its data is connected.
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

  @override
  Widget build(BuildContext context) {
    final module = _selected;
    return ThreePanelScaffold(
      scaffoldKey: _scaffoldKey,
      title: Text(module.label),
      sidebar: AiderSidebar(
        items: _modules,
        selectedId: _selectedId,
        onSelect: _select,
        userName: widget.user.fullName,
        onSignOut: widget.onSignOut,
      ),
      listPanel: AiderListPanel(
        title: module.label,
        items: const [],
        selectedId: null,
        onSelect: (_) {},
      ),
      mainArea: AiderMainArea(child: ModulePlaceholder(item: module)),
    );
  }
}
