import 'package:flutter/material.dart';

import '../../../../../data/repositories/admin_repository.dart';
import '../../../../../domain/models/admin/audit_log_entry.dart';
import '../../../../core/widgets/aider_shell.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../view_models/audit_view_model.dart';
import '../admin_widgets.dart';

/// Read-only audit trail: entries on the left, a readable diff on the right.
class AuditSection extends StatefulWidget {
  const AuditSection({
    super.key,
    required this.repository,
    required this.switcher,
    required this.panelsBuilder,
  });

  final AdminRepository repository;
  final Widget switcher;
  final AdminPanelsBuilder panelsBuilder;

  @override
  State<AuditSection> createState() => _AuditSectionState();
}

class _AuditSectionState extends State<AuditSection> {
  late final AdminAuditViewModel _viewModel = AdminAuditViewModel(
    repository: widget.repository,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _viewModel.range,
    );
    if (picked != null) await _viewModel.setRange(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final vm = _viewModel;
        return widget.panelsBuilder(
          AiderListPanel(
            key: const ValueKey('audit_list'),
            title: 'Auditoría',
            emptyMessage: 'No hay movimientos con estos filtros.',
            header: _filters(vm),
            items: [
              for (final entry in vm.entries)
                AiderListItem(
                  id: entry.id,
                  title:
                      '${auditActionLabel(entry.action)} · ${entry.tableName}',
                  subtitle:
                      '${vm.actorName(entry.actorId)} · '
                      '${formatDateTime(entry.createdAt)}',
                ),
            ],
            selectedId: vm.selected?.id,
            onSelect: vm.select,
            body: vm.loading
                ? const AdminLoading()
                : vm.error != null
                ? AdminLoadError(onRetry: vm.load, message: vm.error)
                : null,
          ),
          AiderMainArea(
            child: vm.selected == null
                ? const EmptyState(
                    icon: Icons.history,
                    title: 'Auditoría',
                    message: 'Elija un movimiento para ver qué cambió.',
                  )
                : _AuditDetail(entry: vm.selected!, actor: vm),
          ),
        );
      },
    );
  }

  Widget _filters(AdminAuditViewModel vm) {
    final range = vm.range;
    return Column(
      children: [
        widget.switcher,
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          key: ValueKey('audit_table_${vm.knownTables.length}'),
          initialValue: vm.tableFilter,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tabla', isDense: true),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todas')),
            for (final table in vm.knownTables)
              DropdownMenuItem(value: table, child: Text(table)),
          ],
          onChanged: vm.setTable,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('audit_range'),
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range),
                label: Text(
                  range == null
                      ? 'Todas las fechas'
                      : '${formatDate(range.start)} - ${formatDate(range.end)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (range != null)
              IconButton(
                tooltip: 'Quitar fechas',
                icon: const Icon(Icons.close),
                onPressed: () => vm.setRange(null),
              ),
          ],
        ),
      ],
    );
  }
}

class _AuditDetail extends StatelessWidget {
  const _AuditDetail({required this.entry, required this.actor});

  final AuditLogEntry entry;
  final AdminAuditViewModel actor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changes = entry.changes;
    return AdminPage(
      children: [
        Text(
          '${auditActionLabel(entry.action)} un registro de ${entry.tableName}',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text('Quién: ${actor.actorName(entry.actorId)}'),
        Text('Cuándo: ${formatDateTime(entry.createdAt)}'),
        SelectableText('Registro: ${entry.recordId}'),
        const SizedBox(height: 16),
        Text('Cambios', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (changes.isEmpty) const Text('No hay diferencias para mostrar.'),
        for (final change in changes)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(change.field, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('Antes: ${change.before ?? '(vacío)'}'),
                  Text('Después: ${change.after ?? '(vacío)'}'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
