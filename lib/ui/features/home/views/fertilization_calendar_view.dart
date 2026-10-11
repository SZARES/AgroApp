import 'package:flutter/material.dart';

import '../../../../domain/models/activity.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/stream_view_model.dart';

/// Calendar-style list of fertilization ("abono") dates for the farmer.
class FertilizationCalendarView extends StatelessWidget {
  const FertilizationCalendarView({super.key, required this.viewModel});

  final StreamViewModel<List<ActivitySummary>> viewModel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario de abonos')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            if (viewModel.isLoading) {
              return const Center(
                child: AppLoadingCard(message: 'Cargando abonos…'),
              );
            }
            if (viewModel.loadFailed) {
              return Center(
                child: Text(
                  'No pudimos leer sus abonos',
                  style: textTheme.titleMedium,
                ),
              );
            }

            final items = viewModel.value;
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.calendar_month,
                title: 'Todavía no registró abonos',
                message:
                    'Cuando registre una actividad de abonamiento, '
                    'aparecerá aquí con su fecha.',
              );
            }

            final groups = _groupByMonth(items);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Fechas en que abonó su terreno',
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                for (final group in groups) ...[
                  Text(group.label, style: textTheme.titleLarge),
                  const SizedBox(height: 12),
                  for (final item in group.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item.date == null
                                          ? '—'
                                          : '${item.date!.day}',
                                      style: textTheme.headlineMedium?.copyWith(
                                        fontSize: 26,
                                        color: scheme.primary,
                                        height: 1,
                                      ),
                                    ),
                                    Text(
                                      item.date == null
                                          ? ''
                                          : _shortMonth(item.date!),
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.date == null
                                          ? 'Sin fecha'
                                          : _longDate(item.date!),
                                      style: textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.parcelName,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (item.quantityLabel != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        item.quantityLabel!,
                                        style: textTheme.bodyMedium,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.grass,
                                size: 28,
                                color: scheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static List<_MonthGroup> _groupByMonth(List<ActivitySummary> items) {
    final map = <String, _MonthGroup>{};
    for (final item in items) {
      final date = item.date;
      final key = date == null
          ? 'sin-fecha'
          : '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final label = date == null
          ? 'Sin fecha'
          : '${_months[date.month - 1]} ${date.year}';
      final group = map.putIfAbsent(
        key,
        () => _MonthGroup(label: label, items: []),
      );
      group.items.add(item);
    }
    return map.values.toList();
  }

  static const _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static String _shortMonth(DateTime date) =>
      _months[date.month - 1].substring(0, 3);

  static String _longDate(DateTime date) =>
      '${date.day} de ${_months[date.month - 1].toLowerCase()} de ${date.year}';
}

class _MonthGroup {
  _MonthGroup({required this.label, required this.items});

  final String label;
  final List<ActivitySummary> items;
}
