import 'package:flutter/material.dart';

import '../../../../domain/models/harvest.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../core/widgets/step_flow.dart';
import '../../../core/widgets/stream_view_model.dart';

/// "Registrar cosecha": the farmer's previous harvests, plus the button that
/// starts a new one.
class HarvestView extends StatelessWidget {
  const HarvestView({
    super.key,
    required this.viewModel,
    required this.recordBuilder,
  });

  final StreamViewModel<List<HarvestSummary>> viewModel;

  /// Builds the one-question-per-screen flow.
  final WidgetBuilder recordBuilder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis cosechas')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final items = viewModel.value;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                PrimaryActionButton(
                  label: 'Registrar cosecha',
                  icon: Icons.agriculture,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: recordBuilder),
                  ),
                ),
                const SizedBox(height: 32),
                Text('Cosechas anteriores', style: textTheme.titleLarge),
                const SizedBox(height: 8),
                if (viewModel.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (viewModel.loadFailed)
                  Text(
                    'No pudimos leer sus cosechas',
                    style: textTheme.titleMedium,
                  )
                else if (items.isEmpty)
                  const SizedBox(
                    height: 240,
                    child: EmptyState(
                      icon: Icons.agriculture,
                      title: 'Todavía no registró ninguna cosecha',
                    ),
                  )
                else
                  for (final harvest in items) _HarvestCard(harvest: harvest),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HarvestCard extends StatelessWidget {
  const _HarvestCard({required this.harvest});

  final HarvestSummary harvest;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lines = [
      '${harvest.parcelName} · ${formatShortDate(harvest.date)}',
      if (harvest.householdLabel != null) 'Casa: ${harvest.householdLabel}',
      if (harvest.surplusLabel != null) 'Para vender: ${harvest.surplusLabel}',
      if (harvest.saleTotal != null)
        'Venta: ${formatSoles(harvest.saleTotal!)}',
      if (harvest.residueLabel != null) 'Rastrojo: ${harvest.residueLabel}',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${harvest.cropName}: ${harvest.quantityLabel}',
                    style: textTheme.titleMedium,
                  ),
                ),
                if (harvest.isPending) const PendingChip(),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in lines) Text(line, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
