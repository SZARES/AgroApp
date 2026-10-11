import 'package:flutter/material.dart';

import '../../../../domain/models/technician_case.dart';
import '../../../../domain/models/technician_farmer.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../view_models/technician_cases_view_model.dart';
import '../view_models/technician_dashboard_view_model.dart';
import 'case_widgets.dart';

/// "Sin datos", "5 h" or "1,5 días": the average time to first attend a case.
String formatAverageResponse(double? days) {
  if (days == null) return 'Sin datos';
  if (days < 1) {
    final hours = (days * 24).round();
    return hours < 1 ? 'Menos de 1 h' : '$hours h';
  }
  final text = days.toStringAsFixed(1);
  return text == '1.0' ? '1 día' : '${text.replaceAll('.', ',')} días';
}

/// KPI cards and the list of cases to attend first. Shared by the web home
/// module and the phone's Inicio tab.
class TechnicianDashboardBody extends StatelessWidget {
  const TechnicianDashboardBody({
    super.key,
    required this.dashboard,
    required this.cases,
    required this.onOpenCase,
  });

  final TechnicianDashboardViewModel dashboard;
  final TechnicianCasesViewModel cases;

  /// Opens the case with the given id (alerts module / full-screen case).
  final ValueChanged<String> onOpenCase;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([dashboard, cases]),
      builder: (context, _) {
        final textTheme = Theme.of(context).textTheme;
        if (dashboard.loadFailed && !dashboard.isLoading) {
          return const EmptyState(
            icon: Icons.error_outline,
            title: 'No pudimos leer su resumen',
            message: 'Cierre esta pantalla y vuelva a abrirla.',
          );
        }
        final attention = cases.attentionCases();
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Resumen de su zona', style: textTheme.headlineSmall),
                const SizedBox(height: 16),
                if (dashboard.isLoading)
                  const KpiGridSkeleton()
                else
                  KpiGrid(kpis: dashboard.kpis),
                const SizedBox(height: 24),
                Text('Para atender hoy', style: textTheme.titleLarge),
                const SizedBox(height: 12),
                if (cases.isLoading)
                  const SizedBox(height: 280, child: SkeletonList(count: 3))
                else if (cases.loadFailed)
                  Text('No pudimos leer los casos', style: textTheme.bodyLarge)
                else if (attention.isEmpty)
                  Text(
                    'No tiene casos pendientes. Buen trabajo.',
                    style: textTheme.bodyLarge,
                  )
                else
                  for (final c in attention) ...[
                    _AttentionTile(item: c, onTap: () => onOpenCase(c.id)),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({required this.item, required this.onTap});

  final TechnicianCase item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        minVerticalPadding: 12,
        title: Text(item.symptom),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.farmerName} · ${item.parcelName}'),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: CaseChips(item: item),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Grid of equal cells: 2 columns on a phone, 4 on a wide screen. Every card
/// of a row takes the height of the tallest one.
class _AdaptiveGrid extends StatelessWidget {
  const _AdaptiveGrid({required this.children});

  final List<Widget> children;

  static const _spacing = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        return Column(
          children: [
            for (var start = 0; start < children.length; start += columns) ...[
              if (start > 0) const SizedBox(height: _spacing),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = start; i < start + columns; i++) ...[
                      if (i > start) const SizedBox(width: _spacing),
                      Expanded(
                        child: i < children.length
                            ? children[i]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Placeholder cards with the shape of [KpiGrid].
class KpiGridSkeleton extends StatelessWidget {
  const KpiGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: _AdaptiveGrid(
        children: [for (var i = 0; i < 8; i++) const SkeletonBox(height: 128)],
      ),
    );
  }
}

class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.kpis});

  final TechnicianKpis kpis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _AdaptiveGrid(
      children: [
        KpiCard(
          icon: Icons.notifications_none,
          label: 'Alertas abiertas',
          value: '${kpis.openAlerts}',
        ),
        KpiCard(
          icon: Icons.priority_high,
          label: 'Urgentes',
          value: '${kpis.urgentAlerts}',
          accent: kpis.urgentAlerts > 0 ? scheme.error : null,
        ),
        KpiCard(
          icon: Icons.event_outlined,
          label: 'Visitas programadas',
          value: '${kpis.scheduledVisits}',
        ),
        KpiCard(
          icon: Icons.handshake_outlined,
          label: 'Atendidos',
          value: '${kpis.attendedCases}',
        ),
        KpiCard(
          icon: Icons.task_alt,
          label: 'Cerrados',
          value: '${kpis.closedCases}',
        ),
        KpiCard(
          icon: Icons.people_outline,
          label: 'Agricultores activos',
          value: '${kpis.activeFarmers}',
        ),
        KpiCard(
          icon: Icons.lightbulb_outline,
          label: 'Recomendaciones confirmadas',
          value:
              '${kpis.recommendationsConfirmed} de ${kpis.recommendationsIssued}',
        ),
        KpiCard(
          icon: Icons.timer_outlined,
          label: 'Tiempo medio de atención',
          value: formatAverageResponse(kpis.avgResponseDays),
        ),
      ],
    );
  }
}

/// One number of the dashboard with its label; the text carries the meaning,
/// the accent colour only reinforces it.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    return Semantics(
      container: true,
      label: '$label: $value${caption == null ? '' : ', $caption'}',
      child: ExcludeSemantics(
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            // Label on top, number pinned to the bottom: numbers of a row
            // share a baseline whatever the label length.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
