import 'package:flutter/material.dart';

import '../../../../../data/repositories/admin_repository.dart';
import '../../../../../domain/models/admin/admin_user.dart';
import '../../../../../domain/models/admin/audit_log_entry.dart';
import '../../../../../domain/models/app_user.dart';
import '../../../../../domain/models/user_role.dart';
import '../../../../../utils/result.dart';
import '../../../../core/widgets/aider_shell.dart';
import '../admin_widgets.dart';

/// The executive Admin dashboard: real-time platform statistics,
/// quick navigation by functional areas, and recent audit activity.
class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({
    super.key,
    required this.user,
    required this.repository,
    required this.onNavigate,
    required this.panelsBuilder,
  });

  final AppUser user;
  final AdminRepository repository;
  final ValueChanged<String> onNavigate;
  final AdminPanelsBuilder panelsBuilder;

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  List<AuditLogEntry> _recentAudit = const [];
  bool _loadingAudit = true;

  @override
  void initState() {
    super.initState();
    _loadRecentAudit();
  }

  Future<void> _loadRecentAudit() async {
    final result = await widget.repository.fetchAuditLogs(limit: 6);
    if (!mounted) return;
    setState(() {
      _recentAudit = switch (result) {
        Ok(:final value) => value,
        Error() => const [],
      };
      _loadingAudit = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminUser>>(
      stream: widget.repository.watchUsers(),
      builder: (context, usersSnapshot) {
        final users = usersSnapshot.data ?? const [];

        return StreamBuilder<List<Map<String, Object?>>>(
          stream: widget.repository.watchRows('zones'),
          builder: (context, zonesSnapshot) {
            final zones = zonesSnapshot.data ?? const [];

            return StreamBuilder<List<Map<String, Object?>>>(
              stream: widget.repository.watchRows('communities'),
              builder: (context, communitiesSnapshot) {
                final communities = communitiesSnapshot.data ?? const [];

                return StreamBuilder<List<Map<String, Object?>>>(
                  stream: widget.repository.watchRows('crops'),
                  builder: (context, cropsSnapshot) {
                    final crops = cropsSnapshot.data ?? const [];

                    return StreamBuilder<List<Map<String, Object?>>>(
                      stream: widget.repository.watchRows('activity_types'),
                      builder: (context, activitiesSnapshot) {
                        final activities = activitiesSnapshot.data ?? const [];

                        return widget.panelsBuilder(
                          _buildListPanel(
                            usersCount: users.length,
                            zonesCount: zones.length,
                            communitiesCount: communities.length,
                            cropsCount: crops.length,
                          ),
                          AiderMainArea(
                            child: _buildMainArea(
                              users: users,
                              zonesCount: zones.length,
                              communitiesCount: communities.length,
                              cropsCount: crops.length,
                              activitiesCount: activities.length,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildListPanel({
    required int usersCount,
    required int zonesCount,
    required int communitiesCount,
    required int cropsCount,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return AiderListPanel(
      title: 'Resumen Ejecutivo',
      header: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Consola Web En Línea',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: scheme.primary,
              ),
            ),
            const Spacer(),
            const Text(
              'v1.0.0',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      items: [
        AiderListItem(
          id: 'kpi_users',
          title: 'Equipo & Usuarios',
          subtitle: '$usersCount usuarios en el sistema',
          leading: const Icon(Icons.people_alt_outlined),
        ),
        AiderListItem(
          id: 'kpi_territory',
          title: 'Territorio',
          subtitle: '$zonesCount zonas · $communitiesCount comunidades',
          leading: const Icon(Icons.map_outlined),
        ),
        AiderListItem(
          id: 'kpi_crops',
          title: 'Cultivos Registrados',
          subtitle: '$cropsCount variedades agrícolas',
          leading: const Icon(Icons.eco_outlined),
        ),
        AiderListItem(
          id: 'kpi_audit',
          title: 'Auditoría',
          subtitle: '${_recentAudit.length} movimientos recientes',
          leading: const Icon(Icons.history_edu_outlined),
        ),
      ],
      selectedId: null,
      onSelect: (id) {
        if (id == 'kpi_users') widget.onNavigate('team');
        if (id == 'kpi_territory') widget.onNavigate('territory');
        if (id == 'kpi_crops') widget.onNavigate('parcels');
        if (id == 'kpi_audit') widget.onNavigate('alerts');
      },
    );
  }

  Widget _buildMainArea({
    required List<AdminUser> users,
    required int zonesCount,
    required int communitiesCount,
    required int cropsCount,
    required int activitiesCount,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final farmersCount =
        users.where((u) => u.role == UserRole.farmer).length;
    final techniciansCount =
        users.where((u) => u.role == UserRole.technician).length;
    final supervisorsCount =
        users.where((u) => u.role == UserRole.supervisor).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
      children: [
        // Hero Welcome Banner
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primary.withValues(alpha: 0.12),
                scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Panel de Administración General',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const AdminChip('Administrador'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hola, ${widget.user.fullName}. Control integral de catálogos agronómicos, gestión territorial, equipo técnico y auditoría.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // KPI Stat Cards Row
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            final itemWidth = isNarrow
                ? constraints.maxWidth
                : (constraints.maxWidth - 36) / 4;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: AdminStatCard(
                    title: 'Usuarios Totales',
                    value: '${users.length}',
                    icon: Icons.people_outline,
                    subtitle:
                        '$farmersCount agricultores · $techniciansCount técnicos · $supervisorsCount sup.',
                    color: Colors.blue.shade700,
                    onTap: () => widget.onNavigate('team'),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AdminStatCard(
                    title: 'Territorio',
                    value: '$zonesCount Zonas',
                    icon: Icons.map_outlined,
                    subtitle: '$communitiesCount comunidades rurales',
                    color: Colors.teal.shade700,
                    onTap: () => widget.onNavigate('territory'),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AdminStatCard(
                    title: 'Catálogos Agrícolas',
                    value: '$cropsCount Cultivos',
                    icon: Icons.eco_outlined,
                    subtitle: '$activitiesCount tipos de actividad',
                    color: Colors.green.shade700,
                    onTap: () => widget.onNavigate('parcels'),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AdminStatCard(
                    title: 'Trazabilidad',
                    value: '${_recentAudit.length}',
                    icon: Icons.history_edu_outlined,
                    subtitle: 'Movimientos de auditoría',
                    color: Colors.deepPurple.shade700,
                    onTap: () => widget.onNavigate('alerts'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),

        // Section header
        Text(
          'Secciones del Sistema',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Quick Navigation by Areas (Grid of Action Cards)
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            final cardWidth = isNarrow
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: AdminActionCard(
                    title: 'Equipo & Usuarios',
                    description:
                        'Gestión completa de agricultores, técnicos y supervisores, asignación de zonas y cuentas.',
                    icon: Icons.groups_outlined,
                    accentColor: Colors.blue.shade700,
                    onTap: () => widget.onNavigate('team'),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: AdminActionCard(
                    title: 'Territorio & Cobertura',
                    description:
                        'Control y edición de zonas geográficas y comunidades rurales del programa agrícola.',
                    icon: Icons.map_outlined,
                    accentColor: Colors.teal.shade700,
                    onTap: () => widget.onNavigate('territory'),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: AdminActionCard(
                    title: 'Parcelas & Cultivos',
                    description:
                        'Catálogo de cultivos, variedades permitidas y asignación de unidades de cosecha.',
                    icon: Icons.landscape_outlined,
                    accentColor: Colors.green.shade700,
                    onTap: () => widget.onNavigate('parcels'),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: AdminActionCard(
                    title: 'Reportes & Métricas',
                    description:
                        'Monitoreo ejecutivo de producción, gastos por categoría y rendimiento agrícola.',
                    icon: Icons.insights_outlined,
                    accentColor: Colors.orange.shade800,
                    onTap: () => widget.onNavigate('reports'),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: AdminActionCard(
                    title: 'Calendario & Actividades',
                    description:
                        'Planificación de labores culturales, temporadas de poda, siembra y cronograma técnico.',
                    icon: Icons.calendar_month_outlined,
                    accentColor: Colors.indigo.shade700,
                    onTap: () => widget.onNavigate('calendar'),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: AdminActionCard(
                    title: 'Administración & Catálogos',
                    description:
                        'Configuración centralizada de precios de referencia, insumos, unidades y equivalencias.',
                    icon: Icons.admin_panel_settings_outlined,
                    accentColor: Colors.purple.shade700,
                    onTap: () => widget.onNavigate('admin'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),

        // Recent Audit Preview
        AdminCard(
          title: 'Actividad Reciente en la Plataforma',
          subtitle: 'Últimos cambios y registros auditados en base de datos',
          icon: Icons.history,
          trailing: TextButton.icon(
            onPressed: () => widget.onNavigate('alerts'),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Ver historial completo'),
          ),
          child: _loadingAudit
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: AdminLoading(),
                )
              : _recentAudit.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No hay registros de auditoría recientes.'),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentAudit.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = _recentAudit[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          entry.action == 'DELETE'
                              ? Icons.delete_outline
                              : entry.action == 'INSERT'
                              ? Icons.add_circle_outline
                              : Icons.edit_outlined,
                          size: 18,
                          color: entry.action == 'DELETE'
                              ? scheme.error
                              : scheme.primary,
                        ),
                      ),
                      title: Text(
                        '${auditActionLabel(entry.action)} en tabla ${entry.tableName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'Registro #${entry.recordId} · ${formatDateTime(entry.createdAt)}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => widget.onNavigate('alerts'),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
