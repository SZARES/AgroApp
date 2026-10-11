import 'package:flutter/material.dart';

import '../../../../domain/models/activity.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/step_flow.dart';
import '../../../core/widgets/stream_view_model.dart';

/// Real data of one activity, read from the device.
class ActivityDetailView extends StatelessWidget {
  const ActivityDetailView({super.key, required this.viewModel});

  final StreamViewModel<ActivityDetail?> viewModel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de actividad')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            final detail = viewModel.value;
            if (viewModel.loadFailed || detail == null) {
              return const EmptyState(
                icon: Icons.edit_note,
                title: 'No encontramos esta actividad',
              );
            }
            final summary = detail.summary;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        summary.typeName,
                        style: textTheme.headlineMedium,
                      ),
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
                        FlowRow(label: 'Parcela', value: summary.parcelName),
                        if (detail.cropName != null)
                          FlowRow(label: 'Cultivo', value: detail.cropName!),
                        FlowRow(
                          label: 'Fecha',
                          value: formatLongDate(summary.date),
                        ),
                        if (detail.productName != null)
                          FlowRow(
                            label: 'Producto',
                            value: detail.productName!,
                          ),
                        if (detail.pruningTypeName != null)
                          FlowRow(
                            label: 'Tipo de poda',
                            value: detail.pruningTypeName!,
                          ),
                        FlowRow(
                          label: 'Cantidad',
                          value: summary.quantityLabel ?? 'Sin cantidad',
                        ),
                        FlowRow(
                          label: 'Gasto',
                          value: summary.expenseAmount == null
                              ? 'Sin gasto'
                              : [
                                  formatSoles(summary.expenseAmount!),
                                  ?detail.expenseCategoryName,
                                ].join(' · '),
                        ),
                        if (detail.notes != null)
                          FlowRow(label: 'Notas', value: detail.notes!),
                      ],
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
}
