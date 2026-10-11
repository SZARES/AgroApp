import 'package:flutter/foundation.dart';

import 'field_def.dart';

/// Join table that limits which units an owner row allows.
@immutable
class AllowedUnitsJoin {
  const AllowedUnitsJoin({
    required this.table,
    required this.ownerColumn,
    this.unitColumn = 'unit_id',
    this.label = 'Unidades permitidas',
  });

  final String table;
  final String ownerColumn;
  final String unitColumn;
  final String label;
}

/// A configurable backend catalog: what to list, how to edit it and how it
/// is stored. Drives the generic admin editor.
@immutable
class CatalogDef {
  const CatalogDef({
    required this.id,
    required this.table,
    required this.title,
    required this.singular,
    required this.fields,
    this.idColumn = 'id',
    this.hasActive = true,
    this.hasSortOrder = true,
    this.titleColumn = 'name',
    this.subtitleColumns = const [],
    this.allowedUnits,
    this.stampsValidation = false,
  });

  /// Section id used by the UI.
  final String id;
  final String table;

  /// Plural title, e.g. "Cultivos".
  final String title;

  /// Singular noun for the CTA, e.g. "cultivo".
  final String singular;
  final List<FieldDef> fields;
  final String idColumn;

  /// False for tables without an `active` column (soft state is `deleted_at`).
  final bool hasActive;
  final bool hasSortOrder;
  final String titleColumn;
  final List<String> subtitleColumns;
  final AllowedUnitsJoin? allowedUnits;

  /// Setting `validated` to true stamps `validated_by`/`validated_at`.
  final bool stampsValidation;

  bool get usesKeyAsId => idColumn != 'id';

  FieldDef? field(String column) {
    for (final field in fields) {
      if (field.column == column) return field;
    }
    return null;
  }
}
