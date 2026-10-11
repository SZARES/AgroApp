import 'package:flutter/foundation.dart';

import 'record_support.dart';

/// Where the harvest went.
enum HarvestDestination { family, surplus, split, other }

/// What was done with the crop residue; [wire] is the backend enum value.
enum ResidueUse {
  compost('compost'),
  otherUse('other_use'),
  notUsed('not_used');

  const ResidueUse(this.wire);

  final String wire;
}

/// Catalogs of the harvest flow.
@immutable
class HarvestCatalog {
  const HarvestCatalog({
    this.buyers = const [],
    this.units = const [],
    this.cropUnitIds = const {},
  });

  final List<CatalogOption> buyers;
  final List<UnitOption> units;

  /// `crop_harvest_units`: crop id -> valid harvest unit ids.
  final Map<String, Set<String>> cropUnitIds;

  /// Harvest units of [cropId]. When the catalog lists none for the crop, every
  /// active unit is offered so the farmer is never blocked.
  List<UnitOption> unitsForCrop(String cropId) {
    final allowed = cropUnitIds[cropId] ?? const <String>{};
    if (allowed.isEmpty) return units;
    return [
      for (final unit in units)
        if (allowed.contains(unit.id)) unit,
    ];
  }
}

@immutable
class SaleDraft {
  const SaleDraft({this.buyerId, this.pricePerUnit});

  final String? buyerId;

  /// Soles per harvest unit; null when unknown.
  final double? pricePerUnit;
}

@immutable
class ResidueDraft {
  const ResidueDraft({required this.use, this.quantity, this.unitId});

  final ResidueUse use;
  final double? quantity;
  final String? unitId;
}

@immutable
class HarvestDraft {
  const HarvestDraft({
    required this.parcel,
    required this.quantity,
    required this.unitId,
    required this.destination,
    this.householdQuantity,
    this.sale,
    this.residue,
  });

  final CycleParcel parcel;
  final double quantity;
  final String unitId;
  final HarvestDestination destination;

  /// Only for [HarvestDestination.split]: the part kept for the family.
  final double? householdQuantity;
  final SaleDraft? sale;
  final ResidueDraft? residue;
}

@immutable
class HarvestSummary {
  const HarvestSummary({
    required this.id,
    required this.parcelName,
    required this.cropName,
    required this.date,
    required this.quantityLabel,
    required this.isPending,
    this.householdLabel,
    this.surplusLabel,
    this.saleTotal,
    this.residueLabel,
  });

  final String id;
  final String parcelName;
  final String cropName;
  final DateTime? date;
  final String quantityLabel;
  final String? householdLabel;
  final String? surplusLabel;
  final double? saleTotal;
  final String? residueLabel;
  final bool isPending;
}
