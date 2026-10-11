import 'package:flutter/material.dart';

import '../../../../domain/models/home_summary.dart';
import '../../../../domain/models/incident_status.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../core/widgets/sync_status_indicator.dart';
import '../../activity_log/views/activity_log_view.dart';
import '../../assistance/views/assistance_view.dart';
import '../../harvest/views/harvest_view.dart';
import '../view_models/home_view_model.dart';

class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.viewModel,
    required this.parcelBuilder,
    required this.reportBuilder,
    required this.reportsBuilder,
    required this.caseBuilder,
  });

  final HomeViewModel viewModel;

  /// Builds the "Mi parcela" screen (it owns its own state).
  final WidgetBuilder parcelBuilder;

  /// Builds the "Reportar problema" flow.
  final WidgetBuilder reportBuilder;

  /// Builds the "Mis reportes" list.
  final WidgetBuilder reportsBuilder;

  /// Builds the status screen of one report.
  final Widget Function(String incidentId) caseBuilder;

  void _open(BuildContext context, Widget view) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => view));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final home = viewModel.home;
            final greeting = viewModel.firstName.isEmpty
                ? 'Hola'
                : 'Hola, ${viewModel.firstName}';
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(greeting, style: textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('¿Qué desea hacer hoy?', style: textTheme.titleMedium),
                const SizedBox(height: 16),
                _ParcelCard(
                  home: home,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: parcelBuilder),
                  ),
                ),
                const SizedBox(height: 16),
                SyncStatusIndicator(
                  summary: viewModel.summary,
                  isSyncing: viewModel.isSyncing,
                  onSyncNow: viewModel.syncNow,
                ),
                const SizedBox(height: 24),
                PrimaryActionButton(
                  label: 'Registrar actividad',
                  icon: Icons.edit_note,
                  onPressed: () => _open(context, const ActivityLogView()),
                ),
                const SizedBox(height: 16),
                PrimaryActionButton(
                  label: 'Reportar problema',
                  icon: Icons.report_problem_outlined,
                  onPressed: () => _open(context, reportBuilder(context)),
                ),
                const SizedBox(height: 16),
                PrimaryActionButton(
                  label: 'Registrar cosecha',
                  icon: Icons.agriculture,
                  onPressed: () => _open(context, const HarvestView()),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _open(context, const AssistanceView()),
                  icon: const Icon(Icons.groups_outlined, size: 28),
                  label: const Text('Mis asistencias'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _open(context, reportsBuilder(context)),
                  icon: const Icon(Icons.fact_check_outlined, size: 28),
                  label: const Text('Mis reportes'),
                ),
                const SizedBox(height: 32),
                Text('Su resumen', style: textTheme.titleLarge),
                const SizedBox(height: 12),
                if (viewModel.loadFailed)
                  Text(
                    'No pudimos leer sus datos guardados',
                    style: textTheme.bodyLarge,
                  )
                else
                  _Summary(
                    home: home,
                    onOpenIncident: home.activeIncidentId == null
                        ? null
                        : () => _open(
                            context,
                            caseBuilder(home.activeIncidentId!),
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

class _ParcelCard extends StatelessWidget {
  const _ParcelCard({required this.home, required this.onTap});

  final HomeSummary home;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = home.parcelName;
    final extra = home.parcelCount > 1 ? ' y ${home.parcelCount - 1} más' : '';
    final subtitle = name == null
        ? 'Toque aquí para agregar su terreno'
        : home.locationLabel ??
              (home.hasLocation ? 'Ubicación guardada' : 'Sin ubicación');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const Icon(Icons.map_outlined, size: 36),
        title: Text(
          name == null ? 'Mi parcela' : '$name$extra',
          style: textTheme.titleMedium,
        ),
        subtitle: Text(subtitle, style: textTheme.bodyLarge),
        trailing: const Icon(Icons.chevron_right, size: 32),
        onTap: onTap,
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.home, this.onOpenIncident});

  final HomeSummary home;
  final VoidCallback? onOpenIncident;

  @override
  Widget build(BuildContext context) {
    final incident = home.activeIncident;
    return Column(
      children: [
        _InfoCard(
          icon: Icons.grass,
          title: 'Último abonamiento',
          value: home.lastFertilization == null
              ? 'Aún no lo registra'
              : formatDate(home.lastFertilization!),
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.lightbulb_outline,
          title: 'Próxima recomendación',
          value:
              home.nextRecommendation ?? 'Por ahora no tiene recomendaciones',
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.report_problem_outlined,
          title: 'Problema activo',
          value: incident == null
              ? 'Sin problemas activos'
              : incidentLabel(incident),
          highlight: incident != null,
          onTap: onOpenIncident,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.scale_outlined,
          title: 'Producción total',
          value: _production(home),
        ),
      ],
    );
  }

  static String _production(HomeSummary home) {
    final kg = home.productionKg;
    if (kg != null) return '${_number(kg)} kg';
    if (home.harvestCount > 0) {
      return home.harvestCount == 1
          ? '1 cosecha registrada'
          : '${home.harvestCount} cosechas registradas';
    }
    return 'Aún no registra cosechas';
  }

  static String _number(double value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0')
        ? text.substring(0, text.length - 2)
        : text.replaceAll('.', ',');
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    this.highlight = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: highlight
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(value, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "5 de mayo de 2026".
String formatDate(DateTime date) =>
    '${date.day} de ${_months[date.month - 1]} de ${date.year}';

String incidentLabel(IncidentStatus status) => switch (status) {
  IncidentStatus.reported => 'Reportado, esperando revisión',
  IncidentStatus.underReview => 'En revisión',
  IncidentStatus.visitScheduled => 'Visita programada',
  IncidentStatus.attended => 'Atendido, en seguimiento',
  IncidentStatus.closed => 'Cerrado',
};
