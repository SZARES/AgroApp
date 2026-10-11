import 'package:flutter/material.dart';

import '../../../../domain/models/incident.dart';
import '../../../../domain/models/incident_status.dart';
import '../../../../domain/models/technician_case.dart';
import '../../../../utils/result.dart';
import '../../../core/widgets/case_photo_strip.dart';
import '../../incident_report/views/incident_status_labels.dart';
import '../view_models/technician_case_view_model.dart';
import 'case_dialogs.dart';
import 'case_widgets.dart';

/// Full-screen case (phone): the body plus an app bar.
class TechnicianCaseDetailView extends StatelessWidget {
  const TechnicianCaseDetailView({super.key, required this.viewModel});

  final TechnicianCaseViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caso')),
      body: SafeArea(child: TechnicianCaseBody(viewModel: viewModel)),
    );
  }
}

/// A case with its actions, shared by the phone and the web console.
class TechnicianCaseBody extends StatelessWidget {
  const TechnicianCaseBody({super.key, required this.viewModel});

  final TechnicianCaseViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final detail = viewModel.detail;
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (viewModel.loadFailed) {
          return const _Message('No pudimos leer este caso');
        }
        if (detail == null) return const _Message('No encontramos este caso');
        return _Content(detail: detail, viewModel: viewModel);
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

String _failureText(Object error) {
  if (error is TechnicianException) {
    return switch (error.failure) {
      TechnicianFailure.notFound => 'No encontramos este caso',
      TechnicianFailure.invalidTransition =>
        'Este caso ya no admite ese cambio',
      TechnicianFailure.noCategory =>
        'Faltan los tipos de asistencia. Conéctese una vez para cargarlos',
      TechnicianFailure.emptyText => 'Escriba el texto antes de guardar',
    };
  }
  return 'No pudimos guardar. Intente otra vez';
}

class _Content extends StatelessWidget {
  const _Content({required this.detail, required this.viewModel});

  final TechnicianCaseDetail detail;
  final TechnicianCaseViewModel viewModel;

  Future<void> _perform(
    BuildContext context,
    Future<Result<void>> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await action();
    final message = switch (result) {
      Ok() => 'Guardado en el dispositivo. Se enviará con conexión.',
      Error(:final error) => _failureText(error),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final summary = detail.summary;
    final reportedAt = summary.reportedAt;
    final busy = viewModel.isBusy;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(summary.symptom, style: textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          '${summary.farmerName} · ${summary.parcelName}'
          '${summary.cropName == null ? '' : ' · ${summary.cropName}'}',
          style: textTheme.bodyLarge,
        ),
        if (detail.farmerPhone != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 18),
              const SizedBox(width: 6),
              SelectableText(detail.farmerPhone!, style: textTheme.bodyLarge),
            ],
          ),
        ],
        const SizedBox(height: 12),
        CaseChips(item: summary),
        if (reportedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            'Reportado el ${formatIncidentDate(reportedAt)}',
            style: textTheme.bodyMedium,
          ),
        ],
        if (detail.description != null) ...[
          const SizedBox(height: 16),
          Text(detail.description!, style: textTheme.bodyLarge),
        ],
        if (detail.photos.isNotEmpty) ...[
          const SizedBox(height: 16),
          CasePhotoStrip(
            photos: detail.photos,
            resolveUrl: viewModel.photoUrl,
          ),
        ],
        if (detail.visit != null) ...[
          const SizedBox(height: 16),
          _VisitCard(visit: detail.visit!),
        ],
        if (summary.isOpen) ...[
          const SizedBox(height: 24),
          Text('Qué hacer', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          _Actions(
            status: summary.status,
            busy: busy,
            onTake: () => _perform(context, viewModel.takeCase),
            onSchedule: () async {
              final plan = await showScheduleVisitDialog(context);
              if (plan == null || !context.mounted) return;
              await _perform(
                context,
                () => viewModel.scheduleVisit(
                  date: plan.date,
                  comment: plan.comment,
                ),
              );
            },
            onAssistance: () async {
              final draft = await showAssistanceDialog(
                context,
                catalog: viewModel.catalog,
              );
              if (draft == null || !context.mounted) return;
              await _perform(
                context,
                () => viewModel.registerAssistance(draft),
              );
            },
            onRecommend: () async {
              final plan = await showRecommendationDialog(context);
              if (plan == null || !context.mounted) return;
              await _perform(
                context,
                () => viewModel.addRecommendation(
                  text: plan.text,
                  dueDate: plan.dueDate,
                ),
              );
            },
            onAttended: () async {
              final comment = await showCommentDialog(
                context,
                title: 'Marcar como atendido',
                confirmLabel: 'Marcar atendido',
                label: 'Comentario (opcional)',
              );
              if (comment == null || !context.mounted) return;
              await _perform(
                context,
                () => viewModel.markAttended(comment: comment),
              );
            },
            onClose: () async {
              final comment = await showCommentDialog(
                context,
                title: 'Cerrar caso',
                confirmLabel: 'Cerrar caso',
                label: 'Comentario de cierre (opcional)',
              );
              if (comment == null || !context.mounted) return;
              await _perform(
                context,
                () => viewModel.closeCase(comment: comment),
              );
            },
          ),
        ],
        const SizedBox(height: 24),
        Text('Recomendaciones', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        if (detail.recommendations.isEmpty)
          Text('Todavía no hay recomendaciones.', style: textTheme.bodyLarge)
        else
          for (final recommendation in detail.recommendations)
            _RecommendationTile(
              recommendation: recommendation,
              busy: busy,
              onConfirm: () => _perform(
                context,
                () => viewModel.confirmRecommendation(recommendation.id),
              ),
            ),
        const SizedBox(height: 24),
        Text('Historial', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        if (detail.history.isEmpty)
          Text('Todavía no hay cambios.', style: textTheme.bodyLarge)
        else
          for (final entry in detail.history) _HistoryTile(entry: entry),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.status,
    required this.busy,
    required this.onTake,
    required this.onSchedule,
    required this.onAssistance,
    required this.onRecommend,
    required this.onAttended,
    required this.onClose,
  });

  final IncidentStatus status;
  final bool busy;
  final VoidCallback onTake;
  final VoidCallback onSchedule;
  final VoidCallback onAssistance;
  final VoidCallback onRecommend;
  final VoidCallback onAttended;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final enabled = !busy;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (status == IncidentStatus.reported)
          FilledButton.icon(
            onPressed: enabled ? onTake : null,
            icon: const Icon(Icons.how_to_reg_outlined),
            label: const Text('Tomar caso'),
          ),
        OutlinedButton.icon(
          onPressed: enabled ? onSchedule : null,
          icon: const Icon(Icons.event_outlined),
          label: Text(
            status == IncidentStatus.visitScheduled
                ? 'Reprogramar visita'
                : 'Programar visita',
          ),
        ),
        OutlinedButton.icon(
          onPressed: enabled ? onAssistance : null,
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Registrar asistencia'),
        ),
        OutlinedButton.icon(
          onPressed: enabled ? onRecommend : null,
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text('Dejar recomendación'),
        ),
        if (status != IncidentStatus.attended)
          OutlinedButton.icon(
            onPressed: enabled ? onAttended : null,
            icon: const Icon(Icons.handshake_outlined),
            label: const Text('Marcar atendido'),
          ),
        OutlinedButton.icon(
          onPressed: enabled ? onClose : null,
          icon: const Icon(Icons.task_alt),
          label: const Text('Cerrar caso'),
        ),
      ],
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit});

  final CaseVisit visit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_available_outlined, size: 32),
        title: Text(
          'Visita programada: ${formatDay(visit.date)}',
          style: textTheme.titleMedium,
        ),
        subtitle: visit.comment == null ? null : Text(visit.comment!),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.recommendation,
    required this.busy,
    required this.onConfirm,
  });

  final CaseRecommendation recommendation;
  final bool busy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final due = recommendation.dueDate;
    return Card(
      child: ListTile(
        leading: Icon(
          recommendation.isConfirmed
              ? Icons.check_circle
              : Icons.radio_button_unchecked,
          color: recommendation.isConfirmed ? scheme.primary : scheme.outline,
          size: 32,
        ),
        title: Text(recommendation.description),
        subtitle: Text(
          [
            recommendation.isConfirmed
                ? 'El agricultor la aplicó'
                : 'Pendiente de aplicar',
            if (due != null) 'Para el ${formatDay(due)}',
            if (recommendation.isPending) 'Por enviar',
          ].join(' · '),
        ),
        isThreeLine: false,
        trailing: recommendation.isConfirmed
            ? null
            : TextButton(
                onPressed: busy ? null : onConfirm,
                child: const Text('Marcar aplicada'),
              ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final IncidentHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final changedAt = entry.changedAt;
    final meta = [
      ?changedAt == null ? null : formatIncidentDate(changedAt),
      ?entry.changedByName,
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: Icon(incidentStatusIcon(entry.status), size: 32),
        title: Text(incidentStatusName(entry.status)),
        subtitle: Text([if (meta.isNotEmpty) meta, ?entry.comment].join('\n')),
        isThreeLine: entry.comment != null,
      ),
    );
  }
}
