import 'package:flutter/material.dart';

import '../../../../domain/models/user_role.dart';

/// Static landing screen for the AIDER roles until their real modules exist.
class StaffHomeView extends StatelessWidget {
  const StaffHomeView({super.key, required this.role, required this.onSignOut})
    : assert(role != UserRole.farmer, 'Farmers land on HomeView');

  final UserRole role;
  final VoidCallback onSignOut;

  static String titleFor(UserRole role) {
    return switch (role) {
      UserRole.technician => 'Panel del técnico',
      UserRole.supervisor => 'Panel del supervisor',
      UserRole.admin => 'Administración',
      UserRole.farmer => 'Mi parcela',
    };
  }

  static List<({IconData icon, String label})> _sectionsFor(UserRole role) {
    return switch (role) {
      UserRole.technician => const [
        (icon: Icons.notifications_active_outlined, label: 'Centro de alertas'),
        (icon: Icons.assignment_outlined, label: 'Registrar asistencia'),
        (icon: Icons.person_search_outlined, label: 'Agricultores'),
      ],
      UserRole.supervisor => const [
        (icon: Icons.insights_outlined, label: 'Indicadores'),
        (icon: Icons.notifications_active_outlined, label: 'Centro de alertas'),
        (icon: Icons.inventory_2_outlined, label: 'Producción y gastos'),
      ],
      UserRole.admin => const [
        (icon: Icons.manage_accounts_outlined, label: 'Usuarios y permisos'),
        (icon: Icons.category_outlined, label: 'Catálogos'),
        (icon: Icons.map_outlined, label: 'Zonas'),
      ],
      UserRole.farmer => const [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(titleFor(role)),
        actions: [
          IconButton(
            onPressed: onSignOut,
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Próximamente', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final section in _sectionsFor(role))
                  Card(
                    child: ListTile(
                      leading: Icon(section.icon, size: 32),
                      title: Text(section.label, style: textTheme.titleMedium),
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
