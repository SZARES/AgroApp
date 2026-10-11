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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _user;
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => AdminPage(
        children: [
          Text(user.fullName, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              AdminChip(roleLabel(user.role)),
              AdminChip(statusLabel(user.status)),
            ],
          ),
          const SizedBox(height: 4),
          Text(user.isFarmer ? 'Entra con su DNI' : 'Entra con su correo'),
          Text(user.loginIdentifier, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('El rol no se puede cambiar; cree una cuenta nueva.'),
          if (_vm.message != null) ...[
            const SizedBox(height: 16),
            AdminBanner(message: _vm.message!, isError: _vm.messageIsError),
          ],
          const SizedBox(height: 24),
          Text('Datos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('detail_name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre completo'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('detail_phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _vm.busy
                  ? null
                  : () => _vm.saveProfile(user, _name.text, _phone.text),
              child: const Text('Guardar datos'),
            ),
          ),
          if (user.isFarmer) ..._farmerSummary(theme),
          const SizedBox(height: 24),
          Text('Estado de la cuenta', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in UserStatus.values)
                if (status != user.status)
                  OutlinedButton(
                    key: ValueKey('status_${status.name}'),
                    onPressed: _vm.busy ? null : () => _changeStatus(status),
                    child: Text('Poner ${statusLabel(status).toLowerCase()}'),
                  ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('reset_password'),
            onPressed: _vm.busy ? null : _resetPassword,
            icon: const Icon(Icons.lock_reset),
            label: const Text('Cambiar contraseña'),
          ),
          if (user.role == UserRole.technician ||
              user.role == UserRole.supervisor) ...[
            const SizedBox(height: 24),
            UserZonesEditor(
              key: ValueKey('zones_${user.id}_${user.zoneIds.join(',')}'),
              viewModel: _vm,
              user: user,
            ),
          ],
          if (user.role == UserRole.technician) ...[
            const SizedBox(height: 24),
            TechnicianParcelsEditor(
              key: ValueKey('parcels_${user.id}_${user.zoneIds.join(',')}'),
              viewModel: _vm,
              user: user,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _farmerSummary(ThemeData theme) {
    final user = _user;
    final last = user.lastActivityAt;
    return [
      const SizedBox(height: 24),
      Text('Resumen del agricultor', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      _line('DNI', user.dni ?? 'Sin DNI'),
      _line('Comunidad', user.communityName ?? 'Sin comunidad'),
      _line('Edad', user.ageRange ?? 'Sin indicar'),
      _line(
        'Última actividad',
        last == null ? 'Todavía sin actividad' : formatDateTime(last),
      ),
    ];
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 140, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
