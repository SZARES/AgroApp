import 'package:flutter/foundation.dart';

/// Why saving a farm record (activity, harvest, external visit) failed.
enum RecordFailure { noCycle, missingChoice, invalidNumber, storage }

class RecordException implements Exception {
  const RecordException(this.failure);

  final RecordFailure failure;

  @override
  String toString() => 'RecordException($failure)';
}

/// A parcel with its active crop cycle, the base of activities and harvests.
@immutable
class CycleParcel {
  const CycleParcel({
    required this.id,
    required this.name,
    required this.cropCycleId,
    required this.cropId,
    required this.cropName,
  });

  final String id;
  final String name;
  final String cropCycleId;
  final String cropId;
  final String cropName;
}

/// Whether the farmer has land and whether that land already has a crop cycle
/// ready for activities / harvests.
@immutable
class RecordLandStatus {
  const RecordLandStatus({
    required this.parcelCount,
    required this.readyParcels,
  });

  static const empty = RecordLandStatus(parcelCount: 0, readyParcels: []);

  /// All of the farmer's parcels (with or without crop).
  final int parcelCount;

  /// Parcels that already have an active crop cycle.
  final List<CycleParcel> readyParcels;

  bool get hasNoParcel => parcelCount == 0;

  /// Has land, but none is ready to record work (missing crop / catalog).
  bool get needsCrop => parcelCount > 0 && readyParcels.isEmpty;
}

/// One entry of a synced catalog (pruning type, buyer, category...).
@immutable
class CatalogOption {
  const CatalogOption({required this.id, required this.name, this.code});

  final String id;
  final String name;
  final String? code;
}

/// A unit of measure from the synced `units` catalog.
@immutable
class UnitOption {
  const UnitOption({
    required this.id,
    required this.name,
    required this.abbreviation,
  });

  final String id;
  final String name;
  final String abbreviation;

  /// Short text to show next to a quantity.
  String get label => abbreviation == 'otro' ? name : abbreviation;
}

/// Parses what a farmer typed ("12,5" or "12.5"); null when empty, negative
/// or not a number.
double? parseDecimal(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite || value < 0) return null;
  return value;
}

/// "12", "12,5": no trailing zeros, comma as decimal separator.
String formatNumber(num value) {
  var text = value.toStringAsFixed(2);
  if (text.contains('.')) {
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  }
  return text.replaceAll('.', ',');
}

/// `yyyy-MM-dd`, the format of the backend `date` columns.
String dateOnly(DateTime date) {
  final d = date.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
