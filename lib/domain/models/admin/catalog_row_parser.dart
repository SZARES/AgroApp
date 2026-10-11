import 'dart:convert';

import 'catalog_def.dart';
import 'field_def.dart';

/// Result of turning raw form values into a database row.
class ParsedCatalogRow {
  const ParsedCatalogRow(this.row, this.errors);

  /// Column -> typed value, ready to send.
  final Map<String, dynamic> row;

  /// Column -> Spanish error. Empty when the row is valid.
  final Map<String, String> errors;

  bool get isValid => errors.isEmpty;
}

/// Validates and converts form input for a [CatalogDef].
///
/// Raw values: text/number/json/date as `String?`, bool as `bool?`,
/// dropdown/reference as the selected value (`String?`).
abstract final class CatalogRowParser {
  static const requiredMessage = 'Complete este campo';

  static ParsedCatalogRow parse(CatalogDef def, Map<String, Object?> raw) {
    final row = <String, dynamic>{};
    final errors = <String, String>{};

    for (final field in def.fields) {
      final value = raw[field.column];
      if (field.kind == FieldKind.bool) {
        row[field.column] = value == true;
        continue;
      }
      final text = value is String ? value.trim() : '';
      if (text.isEmpty) {
        if (field.required) {
          errors[field.column] = requiredMessage;
        } else {
          row[field.column] = null;
        }
        continue;
      }
      switch (field.kind) {
        case FieldKind.number:
          final number = num.tryParse(text.replaceAll(',', '.'));
          if (number == null || number.isNaN || number.isInfinite) {
            errors[field.column] = 'Escriba un número';
          } else if (field.positive ? number <= 0 : number < 0) {
            errors[field.column] = field.positive
                ? 'Debe ser mayor que cero'
                : 'No puede ser negativo';
          } else {
            row[field.column] = number;
          }
        case FieldKind.json:
          try {
            final decoded = jsonDecode(text);
            if (decoded == null) {
              errors[field.column] = 'El valor no puede ser null';
            } else {
              row[field.column] = decoded;
            }
          } on FormatException {
            errors[field.column] = 'JSON no válido';
          }
        case FieldKind.dropdown:
          if (field.options.any((option) => option.value == text)) {
            row[field.column] = text;
          } else {
            errors[field.column] = 'Elija una opción';
          }
        case FieldKind.date:
          if (DateTime.tryParse(text) == null) {
            errors[field.column] = 'Elija una fecha';
          } else {
            row[field.column] = text.substring(0, 10);
          }
        case FieldKind.text || FieldKind.reference || FieldKind.bool:
          row[field.column] = text;
      }
    }

    if (def.hasSortOrder) {
      final text = (raw['sort_order'] is String)
          ? (raw['sort_order'] as String).trim()
          : '';
      if (text.isNotEmpty) {
        final order = int.tryParse(text);
        if (order == null || order < 0) {
          errors['sort_order'] = 'Escriba un número entero';
        } else {
          row['sort_order'] = order;
        }
      }
    }
    return ParsedCatalogRow(row, errors);
  }
}
