import 'package:flutter/foundation.dart';

/// How a catalog field is edited and validated.
enum FieldKind { text, number, bool, dropdown, reference, date, json }

/// One option of a static dropdown.
@immutable
class FieldOption {
  const FieldOption(this.value, this.label);

  final String value;
  final String label;
}

/// One column of a catalog table, described so a single generic editor can
/// build the form.
@immutable
class FieldDef {
  const FieldDef({
    required this.column,
    required this.label,
    this.kind = FieldKind.text,
    this.required = false,
    this.options = const [],
    this.referenceTable,
    this.referenceLabelColumn = 'name',
    this.hint,
    this.multiline = false,
    this.positive = false,
  });

  /// Database column.
  final String column;

  /// Spanish label shown in the form.
  final String label;
  final FieldKind kind;
  final bool required;

  /// Options of a [FieldKind.dropdown].
  final List<FieldOption> options;

  /// Replicated table feeding a [FieldKind.reference] dropdown.
  final String? referenceTable;
  final String referenceLabelColumn;
  final String? hint;
  final bool multiline;

  /// A number that must be greater than zero.
  final bool positive;
}
