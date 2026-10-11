import 'package:flutter/material.dart';

import '../../../../../data/repositories/admin_repository.dart';
import '../../../../../domain/models/admin/catalog_defs.dart';
import '../../../../core/widgets/aider_shell.dart';
import '../admin_widgets.dart';
import '../catalog/catalog_section.dart';

/// Agronomic calendar and activity planning view for the admin console.
class AdminCalendarView extends StatefulWidget {
  const AdminCalendarView({
    super.key,
    required this.repository,
    required this.panelsBuilder,
  });

  final AdminRepository repository;
  final AdminPanelsBuilder panelsBuilder;

  @override
  State<AdminCalendarView> createState() => _AdminCalendarViewState();
}

class _AdminCalendarViewState extends State<AdminCalendarView> {
  String _selectedTab = 'calendar';

  @override
  Widget build(BuildContext context) {
    if (_selectedTab == 'activity_types') {
      return CatalogSection(
        key: const ValueKey('calendar_activity_types'),
        repository: widget.repository,
        section: CatalogDefs.activityTypesSection,
        switcher: _buildTabSwitcher(),
        panelsBuilder: widget.panelsBuilder,
      );
    }
    if (_selectedTab == 'pruning_types') {
      return CatalogSection(
        key: const ValueKey('calendar_pruning_types'),
        repository: widget.repository,
        section: CatalogDefs.pruningTypesSection,
        switcher: _buildTabSwitcher(),
        panelsBuilder: widget.panelsBuilder,
      );
    }

    return widget.panelsBuilder(
      _buildListPanel(),
      AiderMainArea(
        cta: AiderCtaButton(
          label: 'Gestionar tipos de actividad',
          icon: Icons.tune,
          onPressed: () => setState(() => _selectedTab = 'activity_types'),
        ),
        child: _buildMainCalendar(),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedTab,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Vista de Calendario',
            isDense: true,
            prefixIcon: Icon(Icons.calendar_month),
          ),
          items: const [
            DropdownMenuItem(
              value: 'calendar',
              child: Text('Cronograma y Ciclos'),
            ),
            DropdownMenuItem(
              value: 'activity_types',
              child: Text('Tipos de Actividad'),
            ),
            DropdownMenuItem(
              value: 'pruning_types',
              child: Text('Tipos de Poda'),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedTab = val);
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildListPanel() {
    return AiderListPanel(
      title: 'Calendario Agrícola',
      header: _buildTabSwitcher(),
      items: const [
        AiderListItem(
          id: 'campana_2026',
          title: 'Campaña Agrícola 2026',
          subtitle: 'Fase actual: Mantenimiento y Poda',
          leading: Icon(Icons.wb_sunny_outlined),
        ),
        AiderListItem(
          id: 'visitas_tecnicas',
          title: 'Ronda de Asistencias',
          subtitle: '24 visitas programadas este mes',
          leading: Icon(Icons.directions_walk_outlined),
        ),
        AiderListItem(
          id: 'temporada_lluvias',
          title: 'Periodo de Lluvias',
          subtitle: 'Alerta de drenajes y manejo fitosanitario',
          leading: Icon(Icons.water_drop_outlined),
        ),
      ],
      selectedId: 'campana_2026',
      onSelect: (_) {},
    );
  }

  Widget _buildMainCalendar() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 100),
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planificación Agronómica y Ciclos Productivos',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cronograma de labores culturales, ventanas de siembra y visitas técnicas por cultivo.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Current Season Highlight
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_available, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Temporada Actual: Labores de Poda y Fertilización',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recomendada para parcelas de café y cacao. Los técnicos tienen habilitado el registro de poda de formación y fertilización orgánica.',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Timeline of agronomic phases
        AdminCard(
          title: 'Cronograma Anual por Cultivo',
          subtitle: 'Ventanas óptimas para actividades de campo',
          icon: Icons.timeline,
          child: Column(
            children: [
              _buildTimelineItem(
                crop: 'Café (Arábica)',
                phase: 'Poda sanitaria y deschuponado',
                months: 'Mayo - Julio',
                color: Colors.brown,
                icon: Icons.content_cut,
              ),
              const SizedBox(height: 12),
              _buildTimelineItem(
                crop: 'Cacao (Criollo / Forastero)',
                phase: 'Poda de mantenimiento y control de monilia',
                months: 'Junio - Agosto',
                color: Colors.amber.shade800,
                icon: Icons.eco,
              ),
              const SizedBox(height: 12),
              _buildTimelineItem(
                crop: 'Maíz Amarillo Duro',
                phase: 'Siembra en valles interandinos',
                months: 'Septiembre - Noviembre',
                color: Colors.orange,
                icon: Icons.grain,
              ),
              const SizedBox(height: 12),
              _buildTimelineItem(
                crop: 'Plátano / Banano',
                phase: 'Deshoje fitosanitario y deshijado continuo',
                months: 'Todo el año',
                color: Colors.green,
                icon: Icons.calendar_month,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Configured Activities Quick Cards
        AdminCard(
          title: 'Accesos de Configuración Agronómica',
          subtitle: 'Ajusta los catálogos vinculados a este calendario',
          icon: Icons.settings_suggest_outlined,
          child: Row(
            children: [
              Expanded(
                child: ListTile(
                  leading: const Icon(Icons.task_alt, color: Colors.blue),
                  title: const Text('Tipos de Actividad'),
                  subtitle: const Text('Siembra, poda, riego, aplicación'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => setState(() => _selectedTab = 'activity_types'),
                ),
              ),
              const VerticalDivider(),
              Expanded(
                child: ListTile(
                  leading: const Icon(Icons.content_cut, color: Colors.teal),
                  title: const Text('Tipos de Poda'),
                  subtitle: const Text('Formación, producción, rejuvenecimiento'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => setState(() => _selectedTab = 'pruning_types'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required String crop,
    required String phase,
    required String months,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crop, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(phase, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          AdminChip(months, color: color.withValues(alpha: 0.15)),
        ],
      ),
    );
  }
}

