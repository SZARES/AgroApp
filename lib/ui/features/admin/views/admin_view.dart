import 'package:flutter/material.dart';

import '../../../../data/repositories/admin_repository.dart';
import '../../../../domain/models/admin/catalog_defs.dart';
import '../../../../domain/models/app_user.dart';
import '../../../../domain/models/user_role.dart';
import '../../../core/widgets/empty_state.dart';
import 'admin_section_switcher.dart';
import 'admin_widgets.dart';
import 'audit/audit_section.dart';
import 'catalog/catalog_section.dart';
import 'users/users_section.dart';

/// The Administración module: a section switcher over users, catalogs,
/// settings and the audit trail. Only reachable for admins.
class AdminView extends StatefulWidget {
  const AdminView({
    super.key,
    required this.user,
    required this.repository,
    required this.panelsBuilder,
    this.initialSectionId,
  });

  final AppUser user;
  final AdminRepository repository;
  final AdminPanelsBuilder panelsBuilder;
  final String? initialSectionId;

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  late String _sectionId =
      widget.initialSectionId ?? CatalogDefs.sections.first.id;

  AdminSection get _section =>
      CatalogDefs.sections.firstWhere((section) => section.id == _sectionId);

  @override
  Widget build(BuildContext context) {
    if (widget.user.role != UserRole.admin) {
      return widget.panelsBuilder(
        const SizedBox.shrink(),
        const EmptyState(
          icon: Icons.lock_outline,
          title: 'Sin acceso',
          message: 'Solo los administradores pueden entrar a esta sección.',
        ),
      );
    }
    final switcher = AdminSectionSwitcher(
      selectedId: _sectionId,
      onChanged: (id) => setState(() => _sectionId = id),
    );
    final section = _section;
    if (section.id == 'users') {
      return UsersSection(
        key: const ValueKey('section_users'),
        repository: widget.repository,
        switcher: switcher,
        panelsBuilder: widget.panelsBuilder,
      );
    }
    if (section.id == 'audit') {
      return AuditSection(
        key: const ValueKey('section_audit'),
        repository: widget.repository,
        switcher: switcher,
        panelsBuilder: widget.panelsBuilder,
      );
    }
    return CatalogSection(
      key: ValueKey('section_${section.id}'),
      repository: widget.repository,
      section: section,
      switcher: switcher,
      panelsBuilder: widget.panelsBuilder,
    );
  }
}
