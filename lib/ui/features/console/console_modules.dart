import 'package:flutter/material.dart';

import '../../../domain/models/user_role.dart';
import '../../core/widgets/aider_shell.dart';

/// Navigation modules of the AIDER web console, by role.
abstract final class ConsoleModules {
  static const home = AiderNavItem(
    id: 'home',
    label: 'Inicio',
    icon: Icons.home_outlined,
  );
  static const parcels = AiderNavItem(
    id: 'parcels',
    label: 'Parcelas',
    icon: Icons.landscape_outlined,
  );
  static const farmers = AiderNavItem(
    id: 'farmers',
    label: 'Agricultores',
    icon: Icons.people_outline,
  );
  static const territory = AiderNavItem(
    id: 'territory',
    label: 'Territorio',
    icon: Icons.map_outlined,
  );
  static const team = AiderNavItem(
    id: 'team',
    label: 'Equipo',
    icon: Icons.groups_outlined,
  );
  static const reports = AiderNavItem(
    id: 'reports',
    label: 'Reportes',
    icon: Icons.insights_outlined,
  );
  static const calendar = AiderNavItem(
    id: 'calendar',
    label: 'Calendario',
    icon: Icons.calendar_month_outlined,
  );
  static const alerts = AiderNavItem(
    id: 'alerts',
    label: 'Alertas',
    icon: Icons.notifications_none,
    atBottom: true,
  );
  static const admin = AiderNavItem(
    id: 'admin',
    label: 'Administración',
    icon: Icons.admin_panel_settings_outlined,
  );

  /// Modules the console shows for [role]; farmers have no console.
  static List<AiderNavItem> forRole(UserRole role) {
    return switch (role) {
      UserRole.technician => const [home, farmers, alerts],
      UserRole.supervisor => const [home, territory, team, reports],
      UserRole.admin => const [
        home,
        parcels,
        territory,
        team,
        reports,
        calendar,
        admin,
        alerts,
      ],
      UserRole.farmer => const [],
    };
  }
}
