import 'package:flutter/material.dart';

import '../../../../../domain/models/admin/admin_user.dart';
import '../../../../../domain/models/app_user.dart';
import '../../../../../domain/models/user_role.dart';
import '../../view_models/users_view_model.dart';
import '../admin_widgets.dart';
import 'user_assignments.dart';
import 'user_dialogs.dart';

/// Detail of one account: profile, status, password, zones and parcels.
class UserDetailView extends StatefulWidget {
  const UserDetailView({
    super.key,
    required this.viewModel,
    required this.user,
  });

  final AdminUsersViewModel viewModel;
  final AdminUser user;

  @override
  State<UserDetailView> createState() => _UserDetailViewState();
}

class _UserDetailViewState extends State<UserDetailView> {
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _phone = TextEditingController(text: widget.user.phone ?? '');

  AdminUsersViewModel get _vm => widget.viewModel;
  AdminUser get _user => widget.user;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _changeStatus(UserStatus status) async {
    final ok = await confirmAction(
      context,
      title: 'Cambiar estado',
      message:
          '¿Poner a ${_user.fullName} como "${statusLabel(status)}"? '
          '${status == UserStatus.active ? '' : 'No podrá entrar mientras tanto.'}',
      confirmLabel: 'Cambiar',
    );
    if (ok) await _vm.setStatus(_user, status);
  }

  Future<void> _resetPassword() async {
    final password = await askNewPassword(context, _user.fullName);
    if (password != null) await _vm.resetPassword(_user, password);
  }

  static IconData _roleIcon(UserRole role) => switch (role) {
    UserRole.farmer => Icons.agriculture,
    UserRole.technician => Icons.engineering,
    UserRole.supervisor => Icons.supervisor_account,
    UserRole.admin => Icons.admin_panel_settings,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = _user;

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => AdminPage(
        children: [
          // Hero Header Card
          _buildHeroCard(theme, scheme, user),
          if (_vm.message != null) ...[
            const SizedBox(height: 16),
            AdminBanner(message: _vm.message!, isError: _vm.messageIsError),
          ],
          const SizedBox(height: 20),

          // Card 1: Datos Personales
          AdminCard(
            title: 'Datos',
            subtitle: 'Información general de contacto y perfil',
            icon: Icons.person_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('detail_name'),
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('detail_phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _vm.busy
                        ? null
                        : () => _vm.saveProfile(user, _name.text, _phone.text),
                    icon: _vm.busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Guardar datos'),
                  ),
                ),
                if (user.isFarmer) ...[
                  const SizedBox(height: 24),
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 20),
                  ..._farmerSummary(theme, scheme),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Card 2: Estado y Seguridad
          AdminCard(
            title: 'Estado de la cuenta',
            subtitle: 'Gestión de credenciales de acceso y vigencia',
            icon: Icons.lock_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    for (final status in UserStatus.values)
                      if (status != user.status)
                        OutlinedButton.icon(
                          key: ValueKey('status_${status.name}'),
                          onPressed: _vm.busy
                              ? null
                              : () => _changeStatus(status),
                          icon: Icon(
                            status == UserStatus.active
                                ? Icons.check_circle_outline
                                : Icons.block_outlined,
                          ),
                          label: Text(
                            'Poner ${statusLabel(status).toLowerCase()}',
                          ),
                        ),
                    OutlinedButton.icon(
                      key: const ValueKey('reset_password'),
                      onPressed: _vm.busy ? null : _resetPassword,
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('Cambiar contraseña'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Card 3: Asignaciones de Territorio (si aplica)
          if (user.role == UserRole.technician ||
              user.role == UserRole.supervisor) ...[
            const SizedBox(height: 20),
            AdminCard(
              title: 'Asignaciones de territorio',
              subtitle: 'Control de alcance geográfico y parcelas',
              icon: Icons.map_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserZonesEditor(
                    key: ValueKey('zones_${user.id}_${user.zoneIds.join(',')}'),
                    viewModel: _vm,
                    user: user,
                  ),
                  if (user.role == UserRole.technician) ...[
                    const SizedBox(height: 24),
                    Divider(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 20),
                    TechnicianParcelsEditor(
                      key: ValueKey(
                        'parcels_${user.id}_${user.zoneIds.join(',')}',
                      ),
                      viewModel: _vm,
                      user: user,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroCard(ThemeData theme, ColorScheme scheme, AdminUser user) {
    final initial = user.fullName.trim().isEmpty
        ? '?'
        : user.fullName.trim()[0].toUpperCase();

    final isActive = user.status == UserStatus.active;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      initial,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.shade600 : scheme.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        AdminChip(
                          roleLabel(user.role),
                          icon: _roleIcon(user.role),
                        ),
                        AdminChip(
                          statusLabel(user.status),
                          color: isActive
                              ? scheme.primaryContainer
                              : scheme.errorContainer,
                          icon: isActive
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  user.isFarmer ? Icons.credit_card : Icons.alternate_email,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  user.isFarmer ? 'Entra con su DNI' : 'Entra con su correo',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text('•', style: TextStyle(color: scheme.outline)),
                const SizedBox(width: 8),
                SelectableText(
                  user.loginIdentifier,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'El rol no se puede cambiar; cree una cuenta nueva.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _farmerSummary(ThemeData theme, ColorScheme scheme) {
    final user = _user;
    final last = user.lastActivityAt;
    return [
      Text('Resumen del agricultor', style: theme.textTheme.titleMedium),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _line('DNI', user.dni ?? 'Sin DNI', Icons.credit_card),
            const Divider(height: 16),
            _line(
              'Comunidad',
              user.communityName ?? 'Sin comunidad',
              Icons.home_work_outlined,
            ),
            const Divider(height: 16),
            _line(
              'Edad',
              user.ageRange ?? 'Sin indicar',
              Icons.cake_outlined,
            ),
            const Divider(height: 16),
            _line(
              'Última actividad',
              last == null ? 'Todavía sin actividad' : formatDateTime(last),
              Icons.history_outlined,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _line(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}
