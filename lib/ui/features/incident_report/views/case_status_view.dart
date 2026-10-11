import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../domain/models/incident.dart';
import '../../../../domain/models/incident_status.dart';
import '../../../../utils/result.dart';
import '../../../core/widgets/app_loading.dart';
import '../view_models/case_status_view_model.dart';
import 'incident_status_labels.dart';

/// Status of one reported problem: progress, history and photos.
class CaseStatusView extends StatelessWidget {
  const CaseStatusView({super.key, required this.viewModel});

  final CaseStatusViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final detail = viewModel.detail;
        return Scaffold(
          appBar: AppBar(title: const Text('Estado del reporte')),
          body: SafeArea(
            child: viewModel.isLoading
                ? const Center(
                    child: AppLoadingCard(message: 'Cargando reporte…'),
                  )
                : viewModel.loadFailed
                ? const _Message('No pudimos leer este reporte')
                : detail == null
                ? const _Message('No encontramos este reporte')
                : _Body(detail: detail, viewModel: viewModel),
          ),
        );
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

class _Body extends StatelessWidget {
  const _Body({required this.detail, required this.viewModel});

  final IncidentDetail detail;
  final CaseStatusViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final summary = detail.summary;
    final steps = IncidentStatus.values;
    final currentIndex = steps.indexOf(summary.status);
    final reportedAt = summary.reportedAt;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(summary.symptom, style: textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          reportedAt == null
              ? summary.parcelName
              : '${summary.parcelName} · ${formatIncidentDate(reportedAt)}',
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        _SyncChip(isPending: summary.isPending),
        if (detail.description != null) ...[
          const SizedBox(height: 16),
          Text(detail.description!, style: textTheme.bodyLarge),
        ],
        const SizedBox(height: 24),
        for (var i = 0; i < steps.length; i++)
          _TimelineStep(
            label: incidentStatusName(steps[i]),
            done: i <= currentIndex,
            isLast: i == steps.length - 1,
          ),
        if (detail.visit != null) ...[
          const SizedBox(height: 24),
          _VisitCard(visit: detail.visit!, viewModel: viewModel),
        ],
        if (detail.recommendations.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Recomendación del técnico', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final recommendation in detail.recommendations)
            _RecommendationCard(
              recommendation: recommendation,
              viewModel: viewModel,
            ),
        ],
        if (detail.photos.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Fotos', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: detail.photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _PhotoTile(
                photo: detail.photos[i],
                resolveUrl: viewModel.photoUrl,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('Historial', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        if (detail.history.isEmpty)
          Text(
            summary.isPending
                ? 'El historial aparecerá cuando el reporte se envíe.'
                : 'Todavía no hay cambios.',
            style: textTheme.bodyLarge,
          )
        else
          for (final entry in detail.history) _HistoryTile(entry: entry),
      ],
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit, required this.viewModel});

  final CaseVisit visit;
  final CaseStatusViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final date = visit.date;
    final attendance = visit.attendance;
    final assistanceId = visit.assistanceId;

    Future<void> answer(bool arrived) async {
      final result = await viewModel.confirmVisitAttendance(
        assistanceId!,
        arrived: arrived,
      );
      if (result is Error<void>) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No pudimos guardar. Intente otra vez')),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available_outlined, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visit.isCompleted
                            ? 'Visita realizada'
                            : 'Visita programada',
                        style: textTheme.titleMedium,
                      ),
                      Text(
                        [
                          '${date.day.toString().padLeft(2, '0')}/'
                              '${date.month.toString().padLeft(2, '0')}/${date.year}',
                          ?visit.comment,
                        ].join('\n'),
                        style: textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (assistanceId != null) ...[
              const SizedBox(height: 12),
              if (attendance != null)
                Row(
                  children: [
                    Icon(
                      attendance.arrived ? Icons.check_circle : Icons.cancel,
                      color: attendance.arrived ? scheme.primary : scheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          attendance.arrived
                              ? 'Usted indicó que el técnico llegó'
                              : 'Usted indicó que el técnico no llegó',
                          if (attendance.isPending) 'Se enviará con conexión',
                        ].join('. '),
                        style: textTheme.titleMedium,
                      ),
                    ),
                  ],
                )
              else ...[
                Text('¿El técnico llegó a la visita?', style: textTheme.bodyLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => answer(true),
                      icon: const Icon(Icons.check),
                      label: const Text('El técnico llegó'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => answer(false),
                      icon: const Icon(Icons.close),
                      label: const Text('No llegó'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.viewModel,
  });

  final CaseRecommendation recommendation;
  final CaseStatusViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recommendation.description, style: textTheme.bodyLarge),
            const SizedBox(height: 12),
            if (recommendation.isConfirmed)
              Row(
                children: [
                  Icon(Icons.check_circle, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    recommendation.isPending
                        ? 'Lo hizo. Se enviará con conexión'
                        : 'Lo hizo',
                    style: textTheme.titleMedium,
                  ),
                ],
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await viewModel.confirmRecommendation(
                        recommendation.id,
                      );
                      if (result is Error<void>) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('No pudimos guardar. Intente otra vez'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Ya lo hice'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Queda pendiente en este caso'),
                      ),
                    ),
                    icon: const Icon(Icons.schedule),
                    label: const Text('Recordarme luego'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SyncChip extends StatelessWidget {
  const _SyncChip({required this.isPending});

  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(
          isPending ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
          color: isPending ? scheme.secondary : scheme.primary,
        ),
        label: Text(
          isPending ? 'Guardado en el teléfono, por enviar' : 'Enviado',
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
    final textTheme = Theme.of(context).textTheme;
    final changedAt = entry.changedAt;
    final who = entry.changedByName;
    final meta = [
      ?changedAt == null ? null : formatIncidentDate(changedAt),
      ?who,
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: Icon(incidentStatusIcon(entry.status), size: 32),
        title: Text(
          incidentStatusName(entry.status),
          style: textTheme.titleMedium,
        ),
        subtitle: Text(
          [if (meta.isNotEmpty) meta, ?entry.comment].join('\n'),
          style: textTheme.bodyMedium,
        ),
        isThreeLine: entry.comment != null,
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.resolveUrl});

  final IncidentPhotoInfo photo;
  final Future<String?> Function(String storagePath) resolveUrl;

  @override
  Widget build(BuildContext context) {
    final local = photo.localPath;
    final hasLocal = local != null && File(local).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: hasLocal
            ? Image.file(File(local), fit: BoxFit.cover)
            : FutureBuilder<String?>(
                future: resolveUrl(photo.storagePath),
                builder: (context, snapshot) {
                  final url = snapshot.data;
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (url == null) {
                    return const ColoredBox(
                      color: Colors.black26,
                      child: Icon(Icons.image_not_supported_outlined, size: 40),
                    );
                  }
                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Colors.black26,
                      child: Icon(Icons.image_not_supported_outlined, size: 40),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.done,
    required this.isLast,
  });

  final String label;
  final bool done;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = done ? scheme.primary : scheme.outline;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 32,
              color: color,
            ),
            if (!isLast) Container(width: 3, height: 32, color: color),
          ],
        ),
        const SizedBox(width: 16),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: done ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
