import 'package:flutter/material.dart';

import '../../../../domain/models/parcel.dart';
import '../../../../domain/models/technician_farmer.dart';
import '../../../../utils/result.dart';
import '../../../core/widgets/aider_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_badge.dart';
import '../view_models/technician_farmer_view_model.dart';
import '../view_models/technician_farmers_view_model.dart';
import 'case_dialogs.dart';
import 'case_widgets.dart';

/// "3 parcelas", "1 parcela".
String parcelCountLabel(int count) =>
    count == 1 ? '1 parcela' : '$count parcelas';

/// "1 caso abierto", "2 casos abiertos".
String openCasesLabel(int count) =>
    count == 1 ? '1 caso abierto' : '$count casos abiertos';

/// Selectable cards of the farmers list.
List<AiderListItem> farmerListItems(List<TechnicianFarmer> farmers) {
  return [
    for (final f in farmers)
      AiderListItem(
        id: f.id,
        title: f.name,
        subtitle: [
          ?f.communityName,
          parcelCountLabel(f.parcelCount),
        ].join(' · '),
        searchText: f.phone,
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        footer: f.openCaseCount == 0
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: StatusBadge(
                  label: openCasesLabel(f.openCaseCount),
                  color: const Color(0xFFF0701E),
                ),
              ),
      ),
  ];
}

/// Title of the farmers list ("12 agricultores").
String farmersListTitle(int count) =>
    count == 1 ? '1 agricultor' : '$count agricultores';

/// Opens the assistance dialog for the farmer and saves the result, telling
/// the technician what happened.
Future<void> registerFieldAssistanceFlow(
  BuildContext context,
  TechnicianFarmerViewModel viewModel,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final draft = await showAssistanceDialog(
    context,
    catalog: viewModel.catalog,
    parcels: viewModel.detail?.parcels ?? const [],
  );
  if (draft == null) return;
  final result = await viewModel.registerAssistance(draft);
  final message = switch (result) {
    Ok() => 'Guardado en el dispositivo. Se enviará con conexión.',
    Error(:final error) => technicianFailureText(error),
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Full-screen farmer file (phone) with the register-assistance action.
class TechnicianFarmerDetailView extends StatelessWidget {
  const TechnicianFarmerDetailView({
    super.key,
    required this.viewModel,
    required this.onOpenCase,
  });

  final TechnicianFarmerViewModel viewModel;
  final ValueChanged<String> onOpenCase;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final ready = viewModel.detail != null && !viewModel.isLoading;
        return Scaffold(
          appBar: AppBar(title: const Text('Agricultor')),
          body: SafeArea(
            child: TechnicianFarmerDetailBody(
              viewModel: viewModel,
              onOpenCase: onOpenCase,
              showRegisterButton: false,
              bottomPadding: 88,
            ),
          ),
          floatingActionButton: ready
              ? FloatingActionButton.extended(
                  onPressed: viewModel.isBusy
                      ? null
                      : () => registerFieldAssistanceFlow(context, viewModel),
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Registrar asistencia'),
                )
              : null,
        );
      },
    );
  }
}

/// A farmer's file, shared by the phone and the web console.
class TechnicianFarmerDetailBody extends StatelessWidget {
  const TechnicianFarmerDetailBody({
    super.key,
    required this.viewModel,
    required this.onOpenCase,
    this.showRegisterButton = true,
    this.bottomPadding = 20,
  });

  final TechnicianFarmerViewModel viewModel;
  final ValueChanged<String> onOpenCase;

  /// The phone shows the action as a floating button instead.
  final bool showRegisterButton;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) return const SkeletonDetail();
        if (viewModel.loadFailed) {
          return const EmptyState(
            icon: Icons.error_outline,
            title: 'No pudimos leer este agricultor',
            message: 'Cierre esta pantalla y vuelva a abrirla.',
          );
        }
        final detail = viewModel.detail;
        if (detail == null) {
          return const EmptyState(
            icon: Icons.person_off_outlined,
            title: 'No encontramos a este agricultor',
          );
        }
        return _Content(
          detail: detail,
          viewModel: viewModel,
          onOpenCase: onOpenCase,
          showRegisterButton: showRegisterButton,
          bottomPadding: bottomPadding,
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.detail,
    required this.viewModel,
    required this.onOpenCase,
    required this.showRegisterButton,
    required this.bottomPadding,
  });

  final TechnicianFarmerDetail detail;
  final TechnicianFarmerViewModel viewModel;
  final ValueChanged<String> onOpenCase;
  final bool showRegisterButton;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final farmer = detail.farmer;
    final recommendations = detail.recommendations;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      children: [
        Text(farmer.name, style: textTheme.headlineMedium),
        if (farmer.communityName != null) ...[
          const SizedBox(height: 4),
          Text(farmer.communityName!, style: textTheme.bodyLarge),
        ],
        if (farmer.phone != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 18),
              const SizedBox(width: 6),
              SelectableText(farmer.phone!, style: textTheme.bodyLarge),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.landscape_outlined, size: 18),
              label: Text(parcelCountLabel(farmer.parcelCount)),
            ),
            Chip(
              avatar: const Icon(Icons.notifications_none, size: 18),
              label: Text(openCasesLabel(farmer.openCaseCount)),
            ),
            Chip(
              avatar: const Icon(Icons.lightbulb_outline, size: 18),
              label: Text(
                '${recommendations.confirmed} de ${recommendations.issued} '
                'recomendaciones aplicadas',
              ),
            ),
            if (farmer.lastAssistanceDate != null)
              Chip(
                avatar: const Icon(Icons.event_available_outlined, size: 18),
                label: Text(
                  'Última asistencia: ${formatDay(farmer.lastAssistanceDate!)}',
                ),
              ),
          ],
        ),
        if (showRegisterButton) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: viewModel.isBusy
                ? null
                : () => registerFieldAssistanceFlow(context, viewModel),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Registrar asistencia'),
          ),
        ],
        const SizedBox(height: 24),
        Text('Parcelas', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        if (detail.parcels.isEmpty)
          Text('Todavía no tiene parcelas.', style: textTheme.bodyLarge)
        else
          for (final parcel in detail.parcels) _ParcelTile(parcel: parcel),
        const SizedBox(height: 24),
        Text('Incidencias', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        if (detail.cases.isEmpty)
          Text('No reportó problemas.', style: textTheme.bodyLarge)
        else
          for (final c in detail.cases)
            Card(
              child: ListTile(
                minVerticalPadding: 12,
                title: Text(c.symptom),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c.parcelName}'
                      '${c.reportedAt == null ? '' : ' · ${formatDay(c.reportedAt!)}'}',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: CaseChips(item: c),
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenCase(c.id),
              ),
            ),
        const SizedBox(height: 24),
        Text('Asistencias', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        if (detail.assistances.isEmpty)
          Text('Todavía no hay asistencias.', style: textTheme.bodyLarge)
        else
          for (final a in detail.assistances) _AssistanceTile(entry: a),
      ],
    );
  }
}

String _areaText(double hectares) =>
    '${hectares.toStringAsFixed(hectares == hectares.roundToDouble() ? 0 : 2).replaceAll('.', ',')} ha';

class _ParcelTile extends StatelessWidget {
  const _ParcelTile({required this.parcel});

  final Parcel parcel;

  @override
  Widget build(BuildContext context) {
    final area = parcel.areaHectares;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.landscape_outlined, size: 32),
        title: Text(parcel.name),
        subtitle: Text(
          [
            if (area != null) _areaText(area),
            ?parcel.cropName,
            if (parcel.openIncidents > 0) openCasesLabel(parcel.openIncidents),
          ].join(' · '),
        ),
      ),
    );
  }
}

class _AssistanceTile extends StatelessWidget {
  const _AssistanceTile({required this.entry});

  final FarmerAssistanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final date = entry.date;
    return Card(
      child: ListTile(
        leading: Icon(
          entry.isScheduled
              ? Icons.event_outlined
              : Icons.assignment_turned_in_outlined,
          size: 32,
        ),
        title: Text(entry.topic),
        subtitle: Text(
          [
            entry.isScheduled ? 'Programada' : 'Realizada',
            if (date != null) formatDay(date),
            ?entry.parcelName,
            if (entry.isPending) 'Por enviar',
          ].join(' · '),
        ),
      ),
    );
  }
}

/// The web console's farmers module: the list on the left and the selected
/// farmer's file on the right.
class TechnicianFarmersWorkspace extends StatelessWidget {
  const TechnicianFarmersWorkspace({
    super.key,
    required this.viewModel,
    required this.farmerViewModelBuilder,
    required this.onOpenCase,
    required this.panelsBuilder,
  });

  final TechnicianFarmersViewModel viewModel;
  final TechnicianFarmerViewModel Function(String farmerId)
  farmerViewModelBuilder;
  final ValueChanged<String> onOpenCase;
  final Widget Function(Widget listPanel, Widget mainArea) panelsBuilder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final selectedId = viewModel.selectedId;
        final listPanel = Builder(
          builder: (context) => AiderListPanel(
            title: farmersListTitle(viewModel.farmers.length),
            items: farmerListItems(viewModel.farmers),
            selectedId: selectedId,
            emptyMessage: 'Todavía no hay agricultores en su zona.',
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
                    title: 'No pudimos leer los agricultores',
                    message: 'Cierre esta pantalla y vuelva a abrirla.',
                  )
                : null,
          ),
        );
        final Widget main = selectedId == null
            ? const EmptyState(
                icon: Icons.people_outline,
                title: 'Elija un agricultor',
                message:
                    'Aquí verá su ficha: parcelas, problemas reportados y '
                    'asistencias.',
              )
            : AiderMainArea(
                child: _FarmerHost(
                  key: ValueKey(selectedId),
                  farmerId: selectedId,
                  builder: farmerViewModelBuilder,
                  onOpenCase: onOpenCase,
                ),
              );
        return panelsBuilder(listPanel, main);
      },
    );
  }
}

/// Owns the view model of the farmer shown in the main area.
class _FarmerHost extends StatefulWidget {
  const _FarmerHost({
    super.key,
    required this.farmerId,
    required this.builder,
    required this.onOpenCase,
  });

  final String farmerId;
  final TechnicianFarmerViewModel Function(String farmerId) builder;
  final ValueChanged<String> onOpenCase;

  @override
  State<_FarmerHost> createState() => _FarmerHostState();
}

class _FarmerHostState extends State<_FarmerHost> {
  late final TechnicianFarmerViewModel _viewModel = widget.builder(
    widget.farmerId,
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
        child: TechnicianFarmerDetailBody(
          viewModel: _viewModel,
          onOpenCase: widget.onOpenCase,
        ),
      ),
    );
  }
}
