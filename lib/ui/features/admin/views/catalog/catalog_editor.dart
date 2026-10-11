import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../../domain/models/admin/catalog_def.dart';
import '../../../../../domain/models/admin/field_def.dart';
import '../../view_models/catalog_view_model.dart';
import '../admin_widgets.dart';

/// Generic form built from a [CatalogDef]; the same widget edits every
/// catalog.
class CatalogEditor extends StatefulWidget {
  const CatalogEditor({super.key, required this.viewModel, required this.row});

  final AdminCatalogViewModel viewModel;

  /// The row being edited; null when creating.
  final Map<String, dynamic>? row;

  @override
  State<CatalogEditor> createState() => _CatalogEditorState();
}

class _CatalogEditorState extends State<CatalogEditor> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, Object?> _values = {};
  late final Set<String> _allowedUnits;

  AdminCatalogViewModel get _vm => widget.viewModel;
  CatalogDef get _def => _vm.def;
  bool get _isNew => widget.row == null;

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    for (final field in _def.fields) {
      final value = row?[field.column];
      switch (field.kind) {
        case FieldKind.bool:
          _values[field.column] = value == true;
        case FieldKind.dropdown || FieldKind.reference:
          _values[field.column] = value as String?;
        case FieldKind.json:
          _controllers[field.column] = TextEditingController(
            text: value == null
                ? ''
                : const JsonEncoder.withIndent('  ').convert(value),
          );
        case FieldKind.text || FieldKind.number || FieldKind.date:
          _controllers[field.column] = TextEditingController(
            text: value == null ? '' : '$value',
          );
      }
    }
    if (_def.hasSortOrder) {
      _controllers['sort_order'] = TextEditingController(
        text: row?['sort_order'] == null ? '' : '${row!['sort_order']}',
      );
    }
    final ownerId = row?[_def.idColumn];
    _allowedUnits = ownerId == null ? {} : {..._vm.allowedUnitIds('$ownerId')};
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _collect() => {
    for (final field in _def.fields)
      field.column: _controllers.containsKey(field.column)
          ? _controllers[field.column]!.text
          : _values[field.column],
    if (_def.hasSortOrder) 'sort_order': _controllers['sort_order']!.text,
  };

  Future<void> _save() => _vm.save(
    _collect(),
    allowedUnitIds: _def.allowedUnits == null ? null : _allowedUnits,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final errors = _vm.fieldErrors;
        return AdminPage(
          children: [
            Text(
              _isNew ? 'Nuevo: ${_def.singular}' : _vm.title(widget.row!),
              style: theme.textTheme.headlineSmall,
            ),
            if (_vm.message != null) ...[
              const SizedBox(height: 12),
              AdminBanner(message: _vm.message!, isError: _vm.messageIsError),
            ],
            const SizedBox(height: 16),
            for (final field in _def.fields) ...[
              _fieldWidget(field, errors[field.column]),
              const SizedBox(height: 16),
            ],
            if (_def.hasSortOrder) ...[
              TextField(
                key: const ValueKey('field_sort_order'),
                controller: _controllers['sort_order'],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Orden en la lista (opcional)',
                  errorText: errors['sort_order'],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_def.allowedUnits != null) _unitsPicker(_def.allowedUnits!),
            Row(
              children: [
                FilledButton(
                  key: const ValueKey('catalog_save'),
                  onPressed: _vm.busy ? null : _save,
                  child: Text(_isNew ? 'Agregar' : 'Guardar cambios'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _vm.cancelEdit,
                  child: const Text('Cerrar'),
                ),
                const Spacer(),
                if (!_isNew) _stateButton(),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _stateButton() {
    final row = widget.row!;
    if (!_def.hasActive) {
      return TextButton.icon(
        key: const ValueKey('catalog_remove'),
        onPressed: _vm.busy ? null : () => _vm.setActive(row, false),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Quitar de la lista'),
      );
    }
    final active = _vm.isActive(row);
    return TextButton.icon(
      key: const ValueKey('catalog_toggle_active'),
      onPressed: _vm.busy ? null : () => _vm.setActive(row, !active),
      icon: Icon(active ? Icons.visibility_off : Icons.visibility),
      label: Text(active ? 'Desactivar' : 'Activar'),
    );
  }

  Widget _fieldWidget(FieldDef field, String? error) {
    final label = field.required ? '${field.label} *' : field.label;
    switch (field.kind) {
      case FieldKind.bool:
        return SwitchListTile(
          key: ValueKey('field_${field.column}'),
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          value: _values[field.column] == true,
          onChanged: (value) => setState(() => _values[field.column] = value),
        );
      case FieldKind.dropdown:
        return _dropdown(field, label, error, [
          for (final o in field.options) (o.value, o.label),
        ]);
      case FieldKind.reference:
        final rows = _vm.referenceRows(field.referenceTable!);
        return _dropdown(field, label, error, [
          for (final row in rows)
            ('${row['id']}', '${row[field.referenceLabelColumn]}'),
        ]);
      case FieldKind.date:
        return TextField(
          key: ValueKey('field_${field.column}'),
          controller: _controllers[field.column],
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            errorText: error,
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          onTap: () => _pickDate(field),
        );
      case FieldKind.json:
        return TextField(
          key: ValueKey('field_${field.column}'),
          controller: _controllers[field.column],
          minLines: 4,
          maxLines: 12,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(labelText: label, errorText: error),
        );
      case FieldKind.text || FieldKind.number:
        final readOnly =
            _def.usesKeyAsId && field.column == _def.idColumn && !_isNew;
        return TextField(
          key: ValueKey('field_${field.column}'),
          controller: _controllers[field.column],
          readOnly: readOnly,
          minLines: field.multiline ? 2 : 1,
          maxLines: field.multiline ? 5 : 1,
          keyboardType: field.kind == FieldKind.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          decoration: InputDecoration(
            labelText: label,
            hintText: field.hint,
            errorText: error,
          ),
        );
    }
  }

  Widget _dropdown(
    FieldDef field,
    String label,
    String? error,
    List<(String, String)> options,
  ) {
    final current = _values[field.column] as String?;
    final hasCurrent = options.any((o) => o.$1 == current);
    return DropdownButtonFormField<String?>(
      key: ValueKey('field_${field.column}_${options.length}'),
      initialValue: hasCurrent ? current : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: error),
      items: [
        if (!field.required)
          const DropdownMenuItem<String?>(value: null, child: Text('Ninguno')),
        for (final option in options)
          DropdownMenuItem<String?>(value: option.$1, child: Text(option.$2)),
      ],
      onChanged: (value) => _values[field.column] = value,
    );
  }

  Future<void> _pickDate(FieldDef field) async {
    final controller = _controllers[field.column]!;
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      String two(int n) => n.toString().padLeft(2, '0');
      controller.text =
          '${picked.year}-${two(picked.month)}-${two(picked.day)}';
    }
  }

  Widget _unitsPicker(AllowedUnitsJoin join) {
    final units = _vm.unitRows;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(join.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Si no marca ninguna, la app no ofrecerá unidades para esto.',
          ),
          const SizedBox(height: 8),
          if (units.isEmpty) const Text('Todavía no hay unidades creadas.'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final unit in units)
                FilterChip(
                  key: ValueKey('unit_${unit['id']}'),
                  label: Text('${unit['name']} (${unit['abbreviation']})'),
                  selected: _allowedUnits.contains('${unit['id']}'),
                  onSelected: (value) => setState(() {
                    value
                        ? _allowedUnits.add('${unit['id']}')
                        : _allowedUnits.remove('${unit['id']}');
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
