import 'package:flutter/material.dart';

import '../../../../domain/models/incident.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/case_photo_strip.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/step_flow.dart';
import '../view_models/assistance_detail_view_model.dart';
import 'assistance_view.dart';
import '../../../core/widgets/skeleton.dart';

/// Real data of one assistance: observation, recommendations, next review.
class AssistanceDetailView extends StatelessWidget {
  const AssistanceDetailView({super.key, required this.viewModel});

  final AssistanceDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de asistencia')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            if (viewModel.isLoading) {
              return const SkeletonDetail();
              return const Center(
                child: AppLoadingCard(message: 'Cargando asistencia…'),
              );
            }
            final detail = viewModel.value;
            if (viewModel.loadFailed || detail == null) {
              return const EmptyState(
                icon: Icons.groups_outlined,
                title: 'No encontramos esta asistencia',
              );
            }
            final summary = detail.summary;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(summary.topic, style: textTheme.headlineMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(
                      label: providerLabel(summary.provider),
                      color: providerColor(context, summary.provider),
                    ),
                    Text(
                      '${formatLongDate(summary.date)} · '
                      '${statusLabel(summary.status)}',
                      style: textTheme.bodyLarge,
                    ),
                    if (summary.isPending) const PendingChip(),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FlowRow(label: 'Parcela', value: detail.parcelName),
                        if (detail.categoryName != null)
                          FlowRow(label: 'Tema', value: detail.categoryName!),
                        if (summary.technicianName != null)
                          FlowRow(
                            label: 'Técnico',
                            value: summary.technicianName!,
                          ),
                        if (summary.institutionName != null)
                          FlowRow(
                            label: 'Institución',
                            value: summary.institutionName!,
                          ),
                        FlowRow(
                          label: 'Observación',
                          value: detail.observations ?? 'Sin observación',
                        ),
                        FlowRow(
                          label: 'Próxima revisión',
                          value: detail.nextFollowup == null
                              ? 'Sin fecha'
                              : formatLongDate(detail.nextFollowup),
                        ),
                      ],
                    ),
                  ),
                ),
                if (detail.documents.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Documentos', style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  CasePhotoStrip(
                    photos: [
                      for (final d in detail.documents)
                        IncidentPhotoInfo(
                          id: d.id,
                          storagePath: d.storagePath,
                          localPath: d.localPath,
                        ),
                    ],
                    resolveUrl: viewModel.documentUrl,
                  ),
                ],
                const SizedBox(height: 24),
                Text('Recomendaciones', style: textTheme.titleLarge),
                const SizedBox(height: 8),
                if (detail.recommendations.isEmpty)
                  Text(
                    'Esta visita no tiene recomendaciones',
                    style: textTheme.bodyLarge,
                  ),
                for (final recommendation in detail.recommendations)
                  Card(
                    child: CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        recommendation.description,
                        style: textTheme.bodyLarge,
                      ),
                      subtitle: Text(
                        [
                          recommendation.isConfirmed
                              ? 'Ya lo hice'
                              : 'Pendiente',
                          if (recommendation.dueDate != null)
                            'Para ${formatShortDate(recommendation.dueDate)}',
                          if (recommendation.isPending) 'Por enviar',
                        ].join(' · '),
                        style: textTheme.bodyMedium,
                      ),
                      value: recommendation.isConfirmed,
                      // A confirmation is final: it cannot be taken back.
                      onChanged: recommendation.isConfirmed
                          ? null
                          : (_) => viewModel.confirm(recommendation.id),
                    ),
                  ),
                if (viewModel.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    viewModel.errorMessage!,
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
