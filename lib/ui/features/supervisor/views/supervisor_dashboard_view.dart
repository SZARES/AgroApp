import 'package:flutter/material.dart';

import '../../../../data/repositories/supervisor_repository.dart';
import '../../../../domain/models/supervisor_dashboard.dart';
import '../../../core/widgets/aider_shell.dart';
import '../../admin/views/admin_widgets.dart';
import '../view_models/supervisor_dashboard_view_model.dart';

/// The supervisor's Inicio: KPI cards, production/expenses and the
/// distribution of attention per technician. Read-only.
class SupervisorDashboardView extends StatefulWidget {
  const SupervisorDashboardView({
    super.key,
    required this.repository,
    required this.panelsBuilder,
  });

  final SupervisorRepository repository;
  final AdminPanelsBuilder panelsBuilder;

  @override
  State<SupervisorDashboardView> createState() =>
      _SupervisorDashboardViewState();
}

class _SupervisorDashboardViewState extends State<SupervisorDashboardView> {
  static const _allZones = '__all__';

  late final SupervisorDashboardViewModel _viewModel =
      SupervisorDashboardViewModel(repository: widget.repository);

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _onSelectZone(String id) =>
      _viewModel.selectZone(id == _allZones ? null : id);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => widget.panelsBuilder(
        _listPanel(),
        AiderMainArea(child: _main()),
      ),
    );
  }

  Widget _listPanel() {
    final vm = _viewModel;
    return AiderListPanel(
      key: const ValueKey('supervisor_zones'),
      title: 'Zonas',
      items: [
        AiderListItem(
          id: _allZones,
          title: 'Todas las zonas',
          leading: const Icon(Icons.public),
        ),
        for (final zone in vm.zones)
          AiderListItem(
            id: zone.id,
            title: zone.name,
            leading: const Icon(Icons.place_outlined),
          ),
      ],
      selectedId: vm.selectedZoneId ?? _allZones,
      onSelect: _onSelectZone,
      body: vm.loading
          ? const AdminLoading()
          : vm.hasLoadError
              ? AdminLoadError(onRetry: vm.retry)
              : null,
      emptyMessage: 'No hay zonas para mostrar.',
    );
  }

  Widget _main() {
    final vm = _viewModel;
    if (vm.loading) return const AdminLoading();
    if (vm.hasLoadError) return AdminLoadError(onRetry: vm.retry);
    if (vm.isEmpty) {
      return const _DashboardEmpty();
    }
    final metrics = vm.metrics;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          children: [
            _Header(title: vm.scopeTitle, onRefresh: vm.retry),
            const SizedBox(height: 16),
            _KpiRow(metrics: metrics),
            const SizedBox(height: 24),
            _CountsSection(metrics: metrics),
            const SizedBox(height: 24),
            _ProductionSection(metrics: metrics),
            const SizedBox(height: 24),
            _TechnicianLoadSection(load: metrics.technicianLoad),
          ],
        ),
      ),
    );
  }
}

class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Todavía no hay datos de las zonas que supervisa.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onRefresh});

  final String title;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(title, style: theme.textTheme.headlineSmall),
        ),
        IconButton(
          onPressed: onRefresh,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

/// The four headline KPIs.
class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.metrics});

  final SupervisorMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 720;
        final cards = [
          _KpiCard(
            icon: Icons.people_alt_outlined,
            title: 'Adopción',
            value: _percent(metrics.adoptionRate),
            subtitle:
                '${metrics.activeFarmers} de ${metrics.registeredFarmers} agricultores activos',
          ),
          _KpiCard(
            icon: Icons.task_alt,
            title: 'Alertas resueltas',
            value: _percent(metrics.alertResolutionRate),
            subtitle:
                '${metrics.closedAlerts} de ${metrics.totalAlerts} casos cerrados',
          ),
          _KpiCard(
            icon: Icons.fact_check_outlined,
            title: 'Recomendaciones',
            value: _percent(metrics.recommendationRate),
            subtitle:
                '${metrics.confirmedRecommendations} de ${metrics.issuedRecommendations} confirmadas',
          ),
          _KpiCard(
            icon: Icons.schedule,
            title: 'Tiempo de atención',
            value: _hours(metrics.avgResponseHours),
            subtitle: 'promedio desde el reporte',
          ),
        ];
        if (!wide) {
          return Column(
            children: [
              for (final card in cards) ...[
                card,
                const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final card in cards) ...[
              Expanded(child: card),
              if (card != cards.last) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: theme.textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Raw operational counts behind the headline KPIs.
class _CountsSection extends StatelessWidget {
  const _CountsSection({required this.metrics});

  final SupervisorMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Agricultores activos', '${metrics.activeFarmers}'),
      ('Agricultores registrados', '${metrics.registeredFarmers}'),
      ('Alertas abiertas', '${metrics.openAlerts}'),
      ('Casos atendidos', '${metrics.attendedCases}'),
      ('Casos cerrados', '${metrics.closedAlerts}'),
      ('Asistencias técnicas', '${metrics.assistanceCount}'),
    ];
    return _Section(
      title: 'Operación',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in items) _CountChip(label: item.$1, value: item.$2),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Production, household consumption, surplus and expenses. Quantities stay in
/// their original unit (no conversion, per CONTEXT).
class _ProductionSection extends StatelessWidget {
  const _ProductionSection({required this.metrics});

  final SupervisorMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Producción y gastos',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = [
            _UnitColumn(title: 'Producción', items: metrics.production),
            _UnitColumn(title: 'Autoconsumo', items: metrics.household),
            _UnitColumn(title: 'Excedente', items: metrics.surplus),
          ];
          final expenses = _ExpensesCard(
            expensesByCurrency: metrics.expensesByCurrency,
          );
          final wide = constraints.maxWidth > 720;
          if (!wide) {
            return Column(
              children: [
                for (final column in columns) ...[
                  column,
                  const SizedBox(height: 12),
                ],
                expenses,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final column in columns) ...[
                Expanded(child: column),
                const SizedBox(width: 12),
              ],
              Expanded(child: expenses),
            ],
          );
        },
      ),
    );
  }
}

class _UnitColumn extends StatelessWidget {
  const _UnitColumn({required this.title, required this.items});

  final String title;
  final List<UnitQuantity> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text('Sin datos', style: theme.textTheme.bodySmall)
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(item.label)),
                    Text(
                      _quantity(item.quantity),
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _ExpensesCard extends StatelessWidget {
  const _ExpensesCard({required this.expensesByCurrency});

  final Map<String, double> expensesByCurrency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gastos', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (expensesByCurrency.isEmpty)
            Text('Sin datos', style: theme.textTheme.bodySmall)
          else
            for (final entry in expensesByCurrency.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  _money(entry.key, entry.value),
                  style: theme.textTheme.titleLarge,
                ),
              ),
        ],
      ),
    );
  }
}

/// Distribution of attention per technician (never surveillance). Names are
/// hidden under Option B because RLS does not expose technician profiles.
class _TechnicianLoadSection extends StatelessWidget {
  const _TechnicianLoadSection({required this.load});

  final List<TechnicianLoad> load;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _Section(
      title: 'Carga por técnico',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (load.isEmpty)
            Text('Sin datos', style: theme.textTheme.bodySmall)
          else
            for (final tech in load)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.engineering_outlined, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(tech.label)),
                    _loadCell('${tech.assistanceCount} asistencias'),
                    _loadCell('${tech.closedCases} cerrados'),
                    _loadCell('${tech.pendingCases} pendientes'),
                  ],
                ),
              ),
          const SizedBox(height: 8),
          Text(
            'Se muestra la distribución de la atención, no una vigilancia. '
            'Los nombres de los técnicos requieren una función en la base.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _loadCell(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(text),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

// --- formatting helpers -----------------------------------------------------

String _percent(double? rate) {
  if (rate == null) return '—';
  return '${(rate * 100).round()}%';
}

String _hours(double? hours) {
  if (hours == null) return '—';
  final rounded = hours >= 10 ? hours.round() : (hours * 10).round() / 10;
  return '$rounded h';
}

String _quantity(double value) {
  if (value == value.roundToDouble()) return '${value.toInt()}';
  return value.toStringAsFixed(1);
}

String _money(String currency, double amount) {
  final symbol = currency == 'PEN' ? 'S/' : currency;
  final whole = amount.round();
  final digits = whole.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$symbol ${buffer.toString()}';
}
