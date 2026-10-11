import 'package:flutter/foundation.dart';

import 'record_support.dart';

/// An activity type from the synced catalog, with what it asks next.
@immutable
class ActivityTypeOption {
  const ActivityTypeOption({
    required this.id,
    required this.code,
    required this.name,
    required this.requiresProduct,
    required this.requiresPruningType,
  });

  final String id;
  final String code;
  final String name;
  final bool requiresProduct;
  final bool requiresPruningType;
}

/// Every synced catalog the "Registrar actividad" flow reads.
@immutable
class ActivityCatalog {
  const ActivityCatalog({
    this.types = const [],
    this.products = const [],
    this.pruningTypes = const [],
    this.expenseCategories = const [],
    this.units = const [],
    this.typeUnitIds = const {},
    this.productUnitIds = const {},
  });

  final List<ActivityTypeOption> types;
  final List<CatalogOption> products;
  final List<CatalogOption> pruningTypes;
  final List<CatalogOption> expenseCategories;
  final List<UnitOption> units;

  /// `activity_type_units`: activity type id -> allowed unit ids.
  final Map<String, Set<String>> typeUnitIds;

  /// `product_units`: product id -> allowed unit ids.
  final Map<String, Set<String>> productUnitIds;

  /// Units the farmer may use for [typeId] (and [productId] when given),
  /// in catalog order. Empty means the catalog allows no quantity.
  List<UnitOption> unitsFor(String typeId, {String? productId}) {
    final byType = typeUnitIds[typeId] ?? const <String>{};
    final byProduct = productId == null
        ? const <String>{}
        : (productUnitIds[productId] ?? const <String>{});
    final Set<String> allowed;
    if (byProduct.isEmpty) {
      allowed = byType;
    } else if (byType.isEmpty) {
      allowed = byProduct;
    } else {
      final both = byType.intersection(byProduct);
      allowed = both.isEmpty ? byProduct : both;
    }
    return [
      for (final unit in units)
        if (allowed.contains(unit.id)) unit,
    ];
  }
}

/// What the farmer answered in the activity flow.
@immutable
class ActivityDraft {
  const ActivityDraft({
    required this.parcel,
    required this.typeId,
    this.productId,
    this.pruningTypeId,
    this.quantity,
    this.unitId,
    this.expenseAmount,
    this.expenseCategoryId,
  });

  final CycleParcel parcel;
  final String typeId;
  final String? productId;
  final String? pruningTypeId;
  final double? quantity;
  final String? unitId;

  /// Amount in soles; null when nothing was spent.
  final double? expenseAmount;
  final String? expenseCategoryId;
}

@immutable
class ActivitySummary {
  const ActivitySummary({
    required this.id,
    required this.typeName,
    required this.parcelName,
    required this.date,
    required this.isPending,
    this.quantityLabel,
    this.expenseAmount,
  });

  final String id;
  final String typeName;
  final String parcelName;
  final DateTime? date;
  final String? quantityLabel;
  final double? expenseAmount;
  final bool isPending;
}

@immutable
class ActivityDetail {
  const ActivityDetail({
    required this.summary,
    this.cropName,
    this.productName,
    this.pruningTypeName,
    this.expenseCategoryName,
    this.notes,
  });

  final ActivitySummary summary;
  final String? cropName;
  final String? productName;
  final String? pruningTypeName;
  final String? expenseCategoryName;
  final String? notes;
}
