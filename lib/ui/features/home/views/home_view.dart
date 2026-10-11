import 'package:flutter/material.dart';

import '../../../../domain/models/home_summary.dart';
import '../../../../domain/models/incident_status.dart';
import '../view_models/home_view_model.dart';
import 'farmer_account_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.viewModel,
    required this.parcelBuilder,
    required this.activityBuilder,
    required this.harvestBuilder,
    required this.reportBuilder,
    required this.caseBuilder,
    required this.calendarBuilder,
    required this.onSignOut,
  });

  final HomeViewModel viewModel;

  /// Builds the "Mi parcela" screen (it owns its own state).
  final WidgetBuilder parcelBuilder;

  /// Builds the "Registrar actividad" flow (not the list).
  final WidgetBuilder activityBuilder;

  /// Builds the "Registrar cosecha" screen (list and flow).
  final WidgetBuilder harvestBuilder;

  /// Builds the "Reportar problema" flow.
  final WidgetBuilder reportBuilder;

  /// Builds the status screen of one report.
  final Widget Function(String incidentId) caseBuilder;

  /// Builds the fertilization calendar screen.
  final WidgetBuilder calendarBuilder;

  final VoidCallback onSignOut;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _open(BuildContext context, Widget view) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => view));
  }

  void _goTo(int page) {
    setState(() => _page = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            final home = widget.viewModel.home;
            final greeting = widget.viewModel.firstName.isEmpty
                ? 'Hola'
                : 'Hola, ${widget.viewModel.firstName}';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting, style: textTheme.headlineMedium),
                            const SizedBox(height: 4),
                            Text(
                              _page == 0
                                  ? '¿Qué desea hacer hoy?'
                                  : 'Así va su terreno',
                              style: textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _SyncStatusIcon(
                        allSynced: widget.viewModel.summary.isAllSynced,
                        isSyncing: widget.viewModel.isSyncing,
                        onTap: () => _open(
                          context,
                          FarmerAccountView(
                            viewModel: widget.viewModel,
                            onSignOut: widget.onSignOut,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _AccountButton(
                        firstName: widget.viewModel.firstName,
                        onTap: () => _open(
                          context,
                          FarmerAccountView(
                            viewModel: widget.viewModel,
                            onSignOut: widget.onSignOut,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: _ParcelCard(
                    home: home,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: widget.parcelBuilder,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _CarouselTabs(
                    index: _page,
                    onSelect: _goTo,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      _ActionsPage(
                        hasParcel: home.hasParcel,
                        onActivity: () => _open(
                          context,
                          widget.activityBuilder(context),
                        ),
                        onReport: () =>
                            _open(context, widget.reportBuilder(context)),
                        onHarvest: () =>
                            _open(context, widget.harvestBuilder(context)),
                        onParcel: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: widget.parcelBuilder,
                          ),
                        ),
                        onCalendar: () => _open(
                          context,
                          widget.calendarBuilder(context),
                        ),
                      ),
                      _SummaryPage(
                        loadFailed: widget.viewModel.loadFailed,
                        home: home,
                        onOpenIncident: home.activeIncidentId == null
                            ? null
                            : () => _open(
                                context,
                                widget.caseBuilder(home.activeIncidentId!),
                              ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.swipe,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Deslice para cambiar de vista',
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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

class _CarouselTabs extends StatelessWidget {
  const _CarouselTabs({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            Expanded(
              child: _TabChip(
                label: 'Acciones',
                selected: index == 0,
                onTap: () => onSelect(0),
              ),
            ),
            Expanded(
              child: _TabChip(
                label: 'Resumen',
                selected: index == 1,
                onTap: () => onSelect(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionsPage extends StatelessWidget {
  const _ActionsPage({
    required this.hasParcel,
    required this.onActivity,
    required this.onReport,
    required this.onHarvest,
    required this.onParcel,
    required this.onCalendar,
  });

  final bool hasParcel;
  final VoidCallback onActivity;
  final VoidCallback onReport;
  final VoidCallback onHarvest;
  final VoidCallback onParcel;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    if (!hasParcel) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        children: [
          Text(
            'Agregue su terreno para registrar actividades, '
            'problemas y cosechas',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      );
    }

    return GridView.count(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1,
      children: [
        _ActionTile(
          icon: Icons.edit_note,
          label: 'Actividad',
          hint: 'Registrar',
          onTap: onActivity,
        ),
        _ActionTile(
          icon: Icons.report_problem_outlined,
          label: 'Problema',
          hint: 'Reportar',
          accent: true,
          onTap: onReport,
        ),
        _ActionTile(
          icon: Icons.agriculture,
          label: 'Cosecha',
          hint: 'Registrar',
          onTap: onHarvest,
        ),
        _ActionTile(
          icon: Icons.map_outlined,
          label: 'Terreno',
          hint: 'Ver o agregar',
          onTap: onParcel,
        ),
        _ActionTile(
          icon: Icons.calendar_month,
          label: 'Calendario',
          hint: 'Fechas de abono',
          onTap: onCalendar,
        ),
      ],
    );
  }
}

class _SummaryPage extends StatelessWidget {
  const _SummaryPage({
    required this.loadFailed,
    required this.home,
    this.onOpenIncident,
  });

  final bool loadFailed;
  final HomeSummary home;
  final VoidCallback? onOpenIncident;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        Text('Su resumen', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        if (loadFailed)
          Text(
            'No pudimos leer sus datos guardados',
            style: textTheme.bodyLarge,
          )
        else
          _Summary(home: home, onOpenIncident: onOpenIncident),
      ],
    );
  }
}

/// Quiet sync cue beside the account button: icon + color only.
class _SyncStatusIcon extends StatelessWidget {
  const _SyncStatusIcon({
    required this.allSynced,
    required this.isSyncing,
    required this.onTap,
  });

  final bool allSynced;
  final bool isSyncing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isSyncing || !allSynced ? scheme.secondary : scheme.primary;
    final icon = isSyncing
        ? Icons.sync
        : allSynced
        ? Icons.cloud_done
        : Icons.cloud_upload;
    final tip = isSyncing
        ? 'Enviando…'
        : allSynced
        ? 'Todo guardado'
        : 'Hay datos por enviar';

    return Tooltip(
      message: tip,
      child: Material(
        color: color.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(icon, size: 28, color: color, semanticLabel: tip),
          ),
        ),
      ),
    );
  }
}

/// Large square tile for elderly farmers: big icon, short words, easy to tap.
class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.firstName, required this.onTap});

  final String firstName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = firstName.isEmpty
        ? '?'
        : firstName.substring(0, 1).toUpperCase();

    return Tooltip(
      message: 'Mi cuenta',
      child: Material(
        color: scheme.primaryContainer,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: Text(
                initial,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = accent ? scheme.secondary : scheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
            ],
          ),
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
