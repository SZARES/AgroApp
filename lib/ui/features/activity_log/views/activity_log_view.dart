import 'package:flutter/material.dart';

import '../../../../domain/models/activity.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../core/widgets/step_flow.dart';
import '../../../core/widgets/stream_view_model.dart';
import '../../../core/widgets/skeleton.dart';

/// "Registrar actividad": the farmer's activities, plus the button that
/// starts a new one.
class ActivityLogView extends StatelessWidget {
  const ActivityLogView({
    super.key,
    required this.viewModel,
    required this.recordBuilder,
    required this.detailBuilder,
  });

  final StreamViewModel<List<ActivitySummary>> viewModel;

  /// Builds the one-question-per-screen flow.
  final WidgetBuilder recordBuilder;

  /// Builds the detail screen of one activity.
  final Widget Function(String activityId) detailBuilder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis actividades')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final items = viewModel.value;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                PrimaryActionButton(
                  label: 'Registrar actividad',
                  icon: Icons.edit_note,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: recordBuilder),
                  ),
                ),
                const SizedBox(height: 32),
                Text('Últimas actividades', style: textTheme.titleLarge),
                const SizedBox(height: 8),
                if (viewModel.isLoading)
                  const SizedBox(
                    height: 280,
                    child: SkeletonList(count: 3),
                  )
                else if (viewModel.loadFailed)
                  Text(
                    'No pudimos leer sus actividades',
                    style: textTheme.titleMedium,
                  )
                else if (items.isEmpty)
                  const SizedBox(
                    height: 240,
                    child: EmptyState(
                      icon: Icons.edit_note,
                      title: 'Todavía no registró ninguna actividad',
                    ),
                  )
                else
                  for (final activity in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          title: Text(
                            activity.typeName,
                            style: textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            _subtitle(activity),
                            style: textTheme.bodyMedium,
                          ),
                          trailing: activity.isPending
                              ? const PendingChip()
                              : const Icon(Icons.chevron_right, size: 32),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => detailBuilder(activity.id),
                            ),
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

  static String _subtitle(ActivitySummary activity) => [
    '${activity.parcelName} · ${formatShortDate(activity.date)}',
    ?activity.quantityLabel,
    if (activity.expenseAmount != null) formatSoles(activity.expenseAmount!),
  ].join(' · ');
}
