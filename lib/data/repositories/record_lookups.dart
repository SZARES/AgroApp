import '../../domain/models/record_support.dart';
import 'local_store.dart';

/// Shared reads of the farm-record repositories (activities, harvests,
/// assistances) over the local replica.

/// Tables [loadCycleParcels] reads.
const cycleParcelTables = ['parcels', 'crop_cycles', 'crops'];

/// The farmer's parcels that have an active crop cycle (newest planting wins),
/// oldest parcel first.
Future<List<CycleParcel>> loadCycleParcels(
  LocalStore store,
  String farmerId,
) async {
  final parcels = await store.list(
    'parcels',
    where: (r) => r['farmer_id'] == farmerId && r['active'] != false,
  );
  parcels.sort(
    (a, b) =>
        '${a['created_at'] ?? '~'}'.compareTo('${b['created_at'] ?? '~'}'),
  );
  final result = <CycleParcel>[];
  for (final parcel in parcels) {
    final cycles = await store.list(
      'crop_cycles',
      where: (r) => r['parcel_id'] == parcel['id'] && r['status'] == 'active',
    );
    if (cycles.isEmpty) continue;
    cycles.sort(
      (a, b) => '${b['planting_date'] ?? ''}'.compareTo(
        '${a['planting_date'] ?? ''}',
      ),
    );
    final cycle = cycles.first;
    final crop = await store.get('crops', '${cycle['crop_id']}');
    result.add(
      CycleParcel(
        id: '${parcel['id']}',
        name: '${parcel['name']}',
        cropCycleId: '${cycle['id']}',
        cropId: '${cycle['crop_id']}',
        cropName: nonEmptyText(crop?['name']) ?? 'Cultivo',
      ),
    );
  }
  return result;
}

/// Active rows of a catalog table in display order.
Future<List<Map<String, dynamic>>> loadCatalogRows(
  LocalStore store,
  String table,
) async {
  final rows = await store.list(table, where: (r) => r['active'] != false);
  rows.sort((a, b) {
    final byOrder = _int(a['sort_order']).compareTo(_int(b['sort_order']));
    return byOrder != 0 ? byOrder : '${a['name']}'.compareTo('${b['name']}');
  });
  return rows;
}

Future<List<CatalogOption>> loadOptions(LocalStore store, String table) async {
  final rows = await loadCatalogRows(store, table);
  return [
    for (final r in rows)
      CatalogOption(
        id: '${r['id']}',
        name: '${r['name']}',
        code: nonEmptyText(r['code']),
      ),
  ];
}

Future<List<UnitOption>> loadUnits(LocalStore store) async {
  final rows = await loadCatalogRows(store, 'units');
  return [
    for (final r in rows)
      UnitOption(
        id: '${r['id']}',
        name: '${r['name']}',
        abbreviation: '${r['abbreviation']}',
      ),
  ];
}

/// `parent id -> {unit ids}` from a bridge table such as `activity_type_units`.
Future<Map<String, Set<String>>> loadUnitBridge(
  LocalStore store,
  String table,
  String parentColumn,
) async {
  final map = <String, Set<String>>{};
  for (final r in await store.list(table)) {
    map.putIfAbsent('${r[parentColumn]}', () => <String>{}).add('${r['unit_id']}');
  }
  return map;
}

/// Unit lookup by id, including soft-deleted/inactive ones (old records).
Future<Map<String, UnitOption>> loadUnitMap(LocalStore store) async {
  final rows = await store.list('units');
  return {
    for (final r in rows)
      '${r['id']}': UnitOption(
        id: '${r['id']}',
        name: '${r['name']}',
        abbreviation: '${r['abbreviation']}',
      ),
  };
}

/// "20 kg"; null without a quantity.
String? quantityLabel(
  Object? quantity,
  Object? unitId,
  Map<String, UnitOption> units, {
  Object? customUnit,
}) {
  final value = toDouble(quantity);
  if (value == null) return null;
  final custom = nonEmptyText(customUnit);
  final unit = custom ?? units['$unitId']?.label;
  return unit == null ? formatNumber(value) : '${formatNumber(value)} $unit';
}

double? toDouble(Object? value) => switch (value) {
  num() => value.toDouble(),
  String() => double.tryParse(value),
  _ => null,
};

DateTime? parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

String? nonEmptyText(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

int _int(Object? v) => v is num ? v.toInt() : 0;
