import 'package:flutter/material.dart';

import '../../../core/widgets/aider_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../view_models/technician_case_view_model.dart';
import '../view_models/technician_cases_view_model.dart';
import 'case_widgets.dart';
import 'technician_case_detail_view.dart';

/// The technician's web console: alert cards on the left, and the zone map or
/// the selected case on the right.
class TechnicianWorkspace extends StatelessWidget {
  const TechnicianWorkspace({
    super.key,
    required this.viewModel,
    required this.caseViewModelBuilder,
    required this.panelsBuilder,
  });

  final TechnicianCasesViewModel viewModel;
  final TechnicianCaseViewModel Function(String caseId) caseViewModelBuilder;

  /// Places the list panel and the main area in the console layout.
  final Widget Function(Widget listPanel, Widget mainArea) panelsBuilder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final selectedId = viewModel.selectedId;
        final listPanel = Builder(
          builder: (context) => AiderListPanel(
            title: viewModel.openCount == 1
                ? '1 caso abierto'
                : '${viewModel.openCount} casos abiertos',
            header: CaseFilterBar(viewModel: viewModel),
            items: caseListItems(viewModel.filteredCases),
            selectedId: selectedId,
            emptyMessage: emptyCasesMessage(viewModel.filter),
            onSelect: (id) {
              viewModel.select(id);
              final scaffold = Scaffold.maybeOf(context);
              if (scaffold != null && scaffold.isDrawerOpen) {
                scaffold.closeDrawer();
              }
            },
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
        final Widget main = selectedId == null
            ? _MapArea(viewModel: viewModel)
            : AiderMainArea(
                floatingControls: [
                  IconButton.filledTonal(
                    onPressed: () => viewModel.select(null),
                    tooltip: 'Ver mapa',
                    icon: const Icon(Icons.map_outlined),
                  ),
                ],
                child: _CaseHost(
                  key: ValueKey(selectedId),
                  caseId: selectedId,
                  builder: caseViewModelBuilder,
                ),
              );
        return panelsBuilder(listPanel, main);
      },
    );
  }
}

class _MapArea extends StatelessWidget {
  const _MapArea({required this.viewModel});

  final TechnicianCasesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) => CasesMap(
          data: viewModel.map,
          height: constraints.maxHeight,
          onOpenCase: viewModel.select,
        ),
      ),
    );
  }
}

/// Owns the view model of the case shown in the main area.
class _CaseHost extends StatefulWidget {
  const _CaseHost({super.key, required this.caseId, required this.builder});

  final String caseId;
  final TechnicianCaseViewModel Function(String caseId) builder;

  @override
  State<_CaseHost> createState() => _CaseHostState();
}

class _CaseHostState extends State<_CaseHost> {
  late final TechnicianCaseViewModel _viewModel = widget.builder(
    widget.caseId,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: TechnicianCaseBody(viewModel: _viewModel),
      ),
    );
  }
}
