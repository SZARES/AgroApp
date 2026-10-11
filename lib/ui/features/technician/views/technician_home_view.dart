import 'package:flutter/material.dart';

import '../../../core/widgets/aider_shell.dart';
import '../view_models/technician_cases_view_model.dart';
import 'case_widgets.dart';

/// Technician landing screen on a phone: alert inbox and map of the zone.
class TechnicianHomeView extends StatelessWidget {
  const TechnicianHomeView({
    super.key,
    required this.viewModel,
    required this.caseBuilder,
    required this.onSignOut,
  });

  final TechnicianCasesViewModel viewModel;

  /// Full-screen case for the given id.
  final Widget Function(String caseId) caseBuilder;
  final VoidCallback onSignOut;

  void _open(BuildContext context, String id) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => caseBuilder(id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Alertas'),
          actions: [
            IconButton(
              onPressed: onSignOut,
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list_alt_outlined), text: 'Casos'),
              Tab(icon: Icon(Icons.map_outlined), text: 'Mapa'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) => TabBarView(
            children: [
              AiderListPanel(
                title: viewModel.openCount == 1
                    ? '1 caso abierto'
                    : '${viewModel.openCount} casos abiertos',
                items: caseListItems(viewModel.cases),
                selectedId: null,
                onSelect: (id) => _open(context, id),
                emptyMessage: 'No hay casos en su zona por ahora.',
                body: viewModel.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : viewModel.loadFailed
                    ? const Center(child: Text('No pudimos leer los casos'))
                    : null,
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) => CasesMap(
                      data: viewModel.map,
                      height: constraints.maxHeight,
                      onOpenCase: (id) => _open(context, id),
                    ),
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
