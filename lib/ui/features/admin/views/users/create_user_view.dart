import 'package:flutter/material.dart';

import '../../../../../domain/models/admin/admin_user.dart';
import '../../../../../domain/models/admin/create_user_request.dart';
import '../../../../../domain/models/user_role.dart';
import '../../view_models/create_user_view_model.dart';
import '../admin_widgets.dart';

/// "Crear usuario": role first, then the fields that role needs.
class CreateUserView extends StatefulWidget {
  const CreateUserView({
    super.key,
    required this.viewModel,
    required this.onClose,
  });

  final CreateUserViewModel viewModel;
  final VoidCallback onClose;

  @override
  State<CreateUserView> createState() => _CreateUserViewState();
}

class _CreateUserViewState extends State<CreateUserView> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _dni = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  CreateUserViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    for (final controller in [_fullName, _email, _dni, _phone, _password]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _sync() {
    _vm
      ..fullName = _fullName.text
      ..email = _email.text
      ..dni = _dni.text
      ..phone = _phone.text
      ..password = _password.text;
  }

  Future<void> _submit() async {
    _sync();
    final ok = await _vm.submit();
    if (ok) _password.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final created = _vm.created;
        if (created != null) {
          return _Created(viewModel: _vm, onDone: widget.onClose);
        }
        return AdminPage(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Crear usuario',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancelar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AdminCard(
              title: 'Tipo de cuenta',
              subtitle:
                  '¿Qué tipo de cuenta es? El rol no se puede cambiar; cree una cuenta nueva.',
              icon: Icons.manage_accounts_outlined,
              child: _RolePicker(viewModel: _vm),
            ),
            if (_vm.role != null) ..._fields(context),
          ],
        );
      },
    );
  }

  List<Widget> _fields(BuildContext context) {
    final errors = _vm.errors;
    final isFarmer = _vm.role == UserRole.farmer;
    return [
      const SizedBox(height: 20),
      AdminCard(
        title: 'Datos del usuario',
        subtitle: isFarmer
            ? 'Identificación y contacto del agricultor'
            : 'Credenciales y datos de la cuenta',
        icon: Icons.person_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('field_full_name'),
              controller: _fullName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nombre completo',
                errorText: errors[UserFormField.fullName],
              ),
            ),
            const SizedBox(height: 16),
            if (isFarmer)
              TextField(
                key: const ValueKey('field_dni'),
                controller: _dni,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(
                  labelText: 'DNI (8 números)',
                  helperText: 'Con el DNI el agricultor entra a la app',
                  errorText: errors[UserFormField.dni],
                ),
              )
            else
              TextField(
                key: const ValueKey('field_email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  errorText: errors[UserFormField.email],
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('field_phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Teléfono (opcional)',
                errorText: errors[UserFormField.phone],
              ),
            ),
            if (isFarmer) ...[
              const SizedBox(height: 16),
              ..._farmerFields(),
            ] else if (_vm.needsZones) ...[
              const SizedBox(height: 16),
              ..._zoneFields(),
            ],
            const SizedBox(height: 20),
            Divider(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            _passwordField(errors[UserFormField.password]),
            const SizedBox(height: 20),
            if (_vm.error != null) ...[
              AdminBanner(message: _vm.error!, isError: true),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _vm.busy ? null : _submit,
              icon: _vm.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: const Text('Crear cuenta'),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _farmerFields() {
    final zones = _vm.zones;
    return [
      DropdownButtonFormField<String?>(
        key: const ValueKey('field_filter_zone'),
        initialValue: _vm.filterZoneId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Zona'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Todas las zonas')),
          for (final zone in zones)
            DropdownMenuItem(
              value: '${zone['id']}',
              child: Text('${zone['name']}'),
            ),
        ],
        onChanged: _vm.setFilterZone,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        key: ValueKey('field_community_${_vm.filterZoneId}'),
        initialValue: _vm.communityId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Comunidad (opcional)'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Sin comunidad')),
          for (final community in _vm.availableCommunities)
            DropdownMenuItem(
              value: '${community['id']}',
              child: Text('${community['name']}'),
            ),
        ],
        onChanged: _vm.setCommunity,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        key: const ValueKey('field_age_range'),
        initialValue: _vm.ageRange,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Edad (opcional)'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Sin indicar')),
          for (final range in CreateUserRequest.ageRanges)
            DropdownMenuItem(value: range, child: Text(range)),
        ],
        onChanged: _vm.setAgeRange,
      ),
    ];
  }

  List<Widget> _zoneFields() {
    return [
      Text('Zonas de trabajo', style: Theme.of(context).textTheme.titleMedium),
      if (_vm.zones.isEmpty)
        const Text('Todavía no hay zonas. Créelas en "Zonas y comunidades".'),
      for (final zone in _vm.zones)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _vm.zoneIds.contains('${zone['id']}'),
          title: Text('${zone['name']}'),
          onChanged: (value) => _vm.toggleZone('${zone['id']}', value ?? false),
        ),
    ];
  }

  Widget _passwordField(String? error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('field_password'),
          controller: _password,
          obscureText: !_vm.showPassword,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => _sync(),
          decoration: InputDecoration(
            labelText: 'Contraseña (mínimo 8 caracteres)',
            errorText: error,
            suffixIcon: IconButton(
              tooltip: _vm.showPassword ? 'Ocultar' : 'Mostrar',
              icon: Icon(
                _vm.showPassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: _vm.toggleShowPassword,
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('generate_password'),
          onPressed: () {
            _password.text = _vm.generatePassword();
          },
          icon: const Icon(Icons.auto_fix_high),
          label: const Text('Generar contraseña'),
        ),
      ],
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.viewModel});

  final CreateUserViewModel viewModel;

  static IconData _icon(UserRole role) => switch (role) {
    UserRole.farmer => Icons.agriculture,
    UserRole.technician => Icons.engineering,
    UserRole.supervisor => Icons.supervisor_account,
    UserRole.admin => Icons.admin_panel_settings,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final role in CreateUserViewModel.creatableRoles)
          _roleCard(context, role),
      ],
    );
  }

  Widget _roleCard(BuildContext context, UserRole role) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = viewModel.role == role;
    return InkWell(
      key: ValueKey('role_${role.name}'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => viewModel.setRole(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 160,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer.withValues(alpha: 0.4)
              : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.6),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _icon(role),
                size: 26,
                color: isSelected
                    ? scheme.onPrimary
                    : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              roleLabel(role),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? scheme.primary : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown once after creation: identifier and password, copyable.
class _Created extends StatelessWidget {
  const _Created({required this.viewModel, required this.onDone});

  final CreateUserViewModel viewModel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final created = viewModel.created!;
    return AdminPage(
      children: [
        AdminCard(
          icon: Icons.check_circle_outline,
          title: 'Cuenta creada con éxito',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cuenta creada',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(created.loginHint),
              const SizedBox(height: 20),
              CopyField(
                label: created.isDni ? 'DNI' : 'Correo',
                value: created.loginIdentifier,
              ),
              const SizedBox(height: 16),
              CopyField(
                label: 'Contraseña',
                value: viewModel.revealedPassword ?? '',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: scheme.error,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Copie la contraseña ahora: no se volverá a mostrar. '
                        'La persona puede cambiarla más tarde.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('created_done'),
                onPressed: onDone,
                icon: const Icon(Icons.done),
                label: const Text('Listo'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
