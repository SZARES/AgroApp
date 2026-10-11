import 'package:flutter/material.dart';

import '../../../../../data/repositories/admin_repository.dart';
import '../../../../../domain/models/admin/admin_user.dart';
import '../../../../../domain/models/app_user.dart';
import '../../../../../domain/models/user_role.dart';
import '../../../../core/widgets/aider_shell.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../view_models/create_user_view_model.dart';
import '../../view_models/users_view_model.dart';
import '../admin_widgets.dart';
import 'create_user_view.dart';
import 'user_detail_view.dart';

/// Users: searchable cards on the left, detail or create form on the right.
class UsersSection extends StatefulWidget {
  const UsersSection({
    super.key,
    required this.repository,
    required this.switcher,
    required this.panelsBuilder,
  });

  final AdminRepository repository;
  final Widget switcher;
  final AdminPanelsBuilder panelsBuilder;

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection> {
  late final AdminUsersViewModel _viewModel = AdminUsersViewModel(
    repository: widget.repository,
  );
  CreateUserViewModel? _create;

  @override
  void dispose() {
    _create?.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _startCreate() {
    _create?.dispose();
    _create = CreateUserViewModel(
      repository: widget.repository,
      zones: _viewModel.zones,
      communities: _viewModel.communities,
    );
    _viewModel.startCreate();
  }

  void _closeCreate() {
    final created = _create?.created;
    _create?.dispose();
    _create = null;
    if (created != null) {
      _viewModel.onCreated(created.userId);
    }
    _viewModel.cancelCreate();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => widget.panelsBuilder(
        _listPanel(),
        AiderMainArea(
          cta: _viewModel.creating
              ? null
              : AiderCtaButton(
                  label: 'Crear usuario',
                  icon: Icons.person_add_alt_1,
                  onPressed: _startCreate,
                ),
          child: _main(),
        ),
      ),
    );
  }

  Widget _listPanel() {
    final vm = _viewModel;
    final scheme = Theme.of(context).colorScheme;
    return AiderListPanel(
      key: const ValueKey('users_list'),
      title: 'Usuarios',
      header: Column(
        children: [
          widget.switcher,
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<UserRole?>(
                  key: const ValueKey('filter_role'),
                  initialValue: vm.roleFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    for (final role in UserRole.values)
                      DropdownMenuItem(
                        value: role,
                        child: Text(roleLabel(role)),
                      ),
                  ],
                  onChanged: vm.setRoleFilter,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<UserStatus?>(
                  key: const ValueKey('filter_status'),
                  initialValue: vm.statusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    for (final status in UserStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(statusLabel(status)),
                      ),
                  ],
                  onChanged: vm.setStatusFilter,
                ),
              ),
            ],
          ),
        ],
      ),
      items: [
        for (final user in vm.visible)
          AiderListItem(
            id: user.id,
            title: user.fullName.isEmpty ? '(sin nombre)' : user.fullName,
            subtitle: user.subtitle.isEmpty ? null : user.subtitle,
            searchText: '${user.email} ${user.dni ?? ''}',
            leading: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    user.fullName.isEmpty
                        ? '?'
                        : user.fullName[0].toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: user.status == UserStatus.active
                        ? Colors.green.shade600
                        : scheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 1.5),
                  ),
                ),
              ],
            ),
            footer: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  AdminChip(
                    roleLabel(user.role),
                    icon: switch (user.role) {
                      UserRole.farmer => Icons.agriculture,
                      UserRole.technician => Icons.engineering,
                      UserRole.supervisor => Icons.supervisor_account,
                      UserRole.admin => Icons.admin_panel_settings,
                    },
                  ),
                  AdminChip(
                    statusLabel(user.status),
                    color: user.status == UserStatus.active
                        ? scheme.primaryContainer
                        : scheme.errorContainer,
                    icon: user.status == UserStatus.active
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                  ),
                ],
              ),
            ),
          ),
      ],
      selectedId: vm.selected?.id,
      onSelect: vm.select,
      emptyMessage: vm.users.isEmpty
          ? 'Todavía no hay usuarios.'
          : 'Ningún usuario coincide con los filtros.',
      body: vm.loading
          ? const AdminLoading()
          : vm.hasLoadError
          ? AdminLoadError(onRetry: vm.retry)
          : null,
    );
  }

  Widget _main() {
    final vm = _viewModel;
    final create = _create;
    if (vm.creating && create != null) {
      return CreateUserView(
        key: const ValueKey('create_user'),
        viewModel: create,
        onClose: _closeCreate,
      );
    }
    final user = vm.selected;
    if (user != null) {
      return UserDetailView(
        key: ValueKey('user_${user.id}'),
        viewModel: vm,
        user: user,
      );
    }
    return const EmptyState(
      icon: Icons.people_outline,
      title: 'Usuarios',
      message: 'Elija un usuario de la lista o cree uno nuevo.',
    );
  }
}
