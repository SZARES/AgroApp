import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';
import '../view_models/incidents_view_model.dart';
import 'incident_status_labels.dart';
import '../../../core/widgets/skeleton.dart';

/// "Mis reportes": every problem the farmer reported, newest first.
class IncidentsListView extends StatelessWidget {
  const IncidentsListView({
    super.key,
    required this.viewModel,
    required this.caseBuilder,
  });

  final IncidentsViewModel viewModel;
  final Widget Function(String incidentId) caseBuilder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reportes')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            if (viewModel.isLoading) {
              return const SkeletonList(padding: EdgeInsets.all(20));
            }
            if (viewModel.loadFailed) {
              return Center(
                child: Text(
                  'No pudimos leer sus reportes',
                  style: textTheme.titleMedium,
                ),
              );
            }
            final items = viewModel.items;
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.report_problem_outlined,
                title: 'Todavía no reportó ningún problema',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final item = items[i];
                final date = item.reportedAt;
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Icon(incidentStatusIcon(item.status), size: 36),
                    title: Text(item.symptom, style: textTheme.titleMedium),
                    subtitle: Text(
                      [
                        incidentStatusName(item.status),
                        item.parcelName,
                        ?date == null ? null : formatIncidentDate(date),
                        if (item.isPending) 'Por enviar',
                      ].join(' · '),
                      style: textTheme.bodyMedium,
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 32),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => caseBuilder(item.id),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
