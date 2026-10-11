import 'package:flutter/material.dart';

import '../../../core/widgets/aider_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../view_models/technician_cases_view_model.dart';
import '../view_models/technician_dashboard_view_model.dart';
import '../view_models/technician_farmers_view_model.dart';
import 'case_widgets.dart';
import 'technician_dashboard_view.dart';
import 'technician_farmers_view.dart';

/// Technician landing screen on a phone: summary, alert inbox, map of the
/// zone and farmers, behind a bottom navigation bar.
class TechnicianHomeView extends StatefulWidget {
  const TechnicianHomeView({
    super.key,
    required this.viewModel,
    required this.dashboard,
    required this.farmers,
    required this.caseBuilder,
    required this.farmerBuilder,
    required this.onSignOut,
  });

  final TechnicianCasesViewModel viewModel;
  final TechnicianDashboardViewModel dashboard;
  final TechnicianFarmersViewModel farmers;

  /// Full-screen case for the given id.
  final Widget Function(String caseId) caseBuilder;

  /// Full-screen farmer file for the given id.
  final Widget Function(String farmerId) farmerBuilder;
  final VoidCallback onSignOut;

  @override
  State<TechnicianHomeView> createState() => _TechnicianHomeViewState();
}

class _Section {
  const _Section(this.title, this.label, this.icon, this.selectedIcon);

  final String title;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _sections = [
  _Section('Inicio', 'Inicio', Icons.home_outlined, Icons.home),
  _Section('Casos', 'Casos', Icons.list_alt_outlined, Icons.list_alt),
  _Section('Mapa de su zona', 'Mapa', Icons.map_outlined, Icons.map),
  _Section(
    'Agricultores',
    'Agricultores',
    Icons.people_outline,
    Icons.people,
  ),
];

class _TechnicianHomeViewState extends State<TechnicianHomeView> {
  int _index = 0;

  void _push(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void _openCase(String id) => _push(widget.caseBuilder(id));

  @override
  Widget build(BuildContext context) {
    final section = _sections[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text(section.title),
        actions: [
          IconButton(
            onPressed: widget.onSignOut,
            tooltip: 'Cerrar sesión',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          TechnicianDashboardBody(
            dashboard: widget.dashboard,
            cases: widget.viewModel,
            onOpenCase: _openCase,
          ),
          _CasesTab(viewModel: widget.viewModel, onOpenCase: _openCase),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ListenableBuilder(
                listenable: widget.viewModel,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) => CasesMap(
                    data: widget.viewModel.map,
                    height: constraints.maxHeight,
                    onOpenCase: _openCase,
                  ),
                ),
              ),
            ),
          ),
          _FarmersTab(
            viewModel: widget.farmers,
            onOpenFarmer: (id) => _push(widget.farmerBuilder(id)),
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) => NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (var i = 0; i < _sections.length; i++)
              NavigationDestination(
                icon: i == 1 && widget.viewModel.openCount > 0
                    ? Badge(
                        label: Text('${widget.viewModel.openCount}'),
                        child: Icon(_sections[i].icon),
                      )
                    : Icon(_sections[i].icon),
                selectedIcon: Icon(_sections[i].selectedIcon),
                label: _sections[i].label,
              ),
          ],
        ),
      ),
    );
  }
}

class _CasesTab extends StatelessWidget {
  const _CasesTab({required this.viewModel, required this.onOpenCase});

  final TechnicianCasesViewModel viewModel;
  final ValueChanged<String> onOpenCase;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => AiderListPanel(
        title: viewModel.openCount == 1
            ? '1 caso abierto'
            : '${viewModel.openCount} casos abiertos',
        header: CaseFilterBar(viewModel: viewModel),
        items: caseListItems(viewModel.filteredCases),
        selectedId: null,
        onSelect: onOpenCase,
        emptyMessage: emptyCasesMessage(viewModel.filter),
        body: viewModel.isLoading
            ? const SkeletonList()
            : viewModel.loadFailed
            ? const EmptyState(
                icon: Icons.error_outline,
                title: 'No pudimos leer los casos',
                message: 'Cierre esta pantalla y vuelva a abrirla.',
              )
            : null,
      ),
    );
  }
}

class _FarmersTab extends StatelessWidget {
  const _FarmersTab({required this.viewModel, required this.onOpenFarmer});

  final TechnicianFarmersViewModel viewModel;
  final ValueChanged<String> onOpenFarmer;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => AiderListPanel(
        title: farmersListTitle(viewModel.farmers.length),
        items: farmerListItems(viewModel.farmers),
        selectedId: null,
        onSelect: onOpenFarmer,
        emptyMessage: 'Todavía no hay agricultores en su zona.',
        body: viewModel.isLoading
            ? const SkeletonList()
            : viewModel.loadFailed
            ? const EmptyState(
                icon: Icons.error_outline,
                title: 'No pudimos leer los agricultores',
                message: 'Cierre esta pantalla y vuelva a abrirla.',
              )
            : null,
      ),
    );
  }
}
