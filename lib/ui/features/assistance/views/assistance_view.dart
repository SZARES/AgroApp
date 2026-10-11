import 'package:flutter/material.dart';

import '../../../../domain/models/assistance.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/step_flow.dart';
import '../../../core/widgets/stream_view_model.dart';
import '../../../core/widgets/skeleton.dart';

/// "Mis asistencias": every assistance of the farmer (AIDER, SENASA, other),
/// plus the button to record an external visit.
class AssistanceView extends StatelessWidget {
  const AssistanceView({
    super.key,
    required this.viewModel,
    required this.detailBuilder,
    required this.externalVisitBuilder,
  });

  final StreamViewModel<List<AssistanceSummary>> viewModel;

  /// Builds the detail screen of one assistance.
  final Widget Function(String assistanceId) detailBuilder;

  /// Builds the "Registrar visita externa" flow.
  final WidgetBuilder externalVisitBuilder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis asistencias')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final items = viewModel.value;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                PrimaryActionButton(
                  label: 'Registrar visita externa',
                  icon: Icons.add_a_photo_outlined,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: externalVisitBuilder),
                  ),
                ),
                const SizedBox(height: 24),
                if (viewModel.isLoading)
                  const SizedBox(
                    height: 280,
                    child: SkeletonList(count: 3),
                  )
                else if (viewModel.loadFailed)
                  Text(
                    'No pudimos leer sus asistencias',
                    style: textTheme.titleMedium,
                  )
                else if (items.isEmpty)
                  const SizedBox(
                    height: 240,
                    child: EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'Todavía no tiene asistencias',
                      message:
                          'Aquí verá las visitas de AIDER y de otras '
                          'instituciones',
                    ),
                  )
                else
                  for (final assistance in items)
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        title: Text(
                          assistance.topic,
                          style: textTheme.titleMedium,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              StatusBadge(
                                label: providerLabel(assistance.provider),
                                color: providerColor(
                                  context,
                                  assistance.provider,
                                ),
                              ),
                              Text(
                                _subtitle(assistance),
                                style: textTheme.bodyMedium,
                              ),
                              if (assistance.isPending) const PendingChip(),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 32),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => detailBuilder(assistance.id),
                          ),
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _subtitle(AssistanceSummary a) => [
    formatShortDate(a.date),
    statusLabel(a.status),
    ?a.technicianName,
  ].join(' · ');
}

String providerLabel(AssistanceProvider provider) => switch (provider) {
  AssistanceProvider.aider => 'AIDER',
  AssistanceProvider.senasa => 'SENASA',
  AssistanceProvider.other => 'Otra institución',
};

Color providerColor(BuildContext context, AssistanceProvider provider) {
  final scheme = Theme.of(context).colorScheme;
  return switch (provider) {
    AssistanceProvider.aider => scheme.primary,
    AssistanceProvider.senasa => scheme.secondary,
    AssistanceProvider.other => scheme.onSurfaceVariant,
  };
}

String statusLabel(AssistanceStatus status) => switch (status) {
  AssistanceStatus.scheduled => 'Programada',
  AssistanceStatus.completed => 'Realizada',
  AssistanceStatus.cancelled => 'Cancelada',
};
