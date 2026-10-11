import '../../domain/models/record_support.dart';
import '../../domain/models/sync_op.dart';
import 'local_store.dart';

/// Shared reads of the farm-record repositories (activities, harvests,
/// assistances) over the local replica.

/// Tables [loadCycleParcels] reads.
const cycleParcelTables = ['parcels', 'crop_cycles', 'crops'];

/// Active crop cycle for a parcel: reuses one if present, otherwise creates a
/// default (Maíz when available) so farmers can record work right after
/// adding land without waiting for a technician.
Future<({String cycleId, String cropId, String cropName})?> ensureActiveCycle(
  LocalStore store,
  String parcelId, {
  DateTime Function()? clock,
}) async {
  final cycles = await store.list(
    'crop_cycles',
    where: (r) => r['parcel_id'] == parcelId && r['status'] == 'active',
  );
  if (cycles.isNotEmpty) {
    cycles.sort(
      (a, b) => '${b['planting_date'] ?? ''}'.compareTo(
        '${a['planting_date'] ?? ''}',
      ),
    );
    final cycle = cycles.first;
    final crop = await store.get('crops', '${cycle['crop_id']}');
    return (
      cycleId: '${cycle['id']}',
      cropId: '${cycle['crop_id']}',
      cropName: nonEmptyText(crop?['name']) ?? 'Cultivo',
    );
  }

  final crops = await loadCatalogRows(store, 'crops');
  if (crops.isEmpty) return null;
  final crop = _defaultCrop(crops);
  final cropId = '${crop['id']}';
  final cycleId = store.newId();
  final today = dateOnly(clock?.call() ?? DateTime.now());
  await store.save(
    table: 'crop_cycles',
    id: cycleId,
    op: SyncOp.upsert,
    row: {
      'parcel_id': parcelId,
      'crop_id': cropId,
      'planting_date': today,
      'status': 'active',
    },
  );
  return (
    cycleId: cycleId,
    cropId: cropId,
    cropName: nonEmptyText(crop['name']) ?? 'Cultivo',
  );
}

Map<String, dynamic> _defaultCrop(List<Map<String, dynamic>> crops) {
  for (final crop in crops) {
    final code = '${crop['code']}'.toLowerCase();
    final name = '${crop['name']}'.toLowerCase();
    if (code == 'maiz' || name.contains('maíz') || name.contains('maiz')) {
      return crop;
    }
  }
  return crops.first;
}

/// The farmer's parcels with an active crop cycle (creates a default cycle
/// when the parcel has none). Oldest parcel first.
Future<List<CycleParcel>> loadCycleParcels(
  LocalStore store,
  String farmerId, {
  DateTime Function()? clock,
}) async {
  final status = await loadRecordLandStatus(
    store,
    farmerId,
    clock: clock,
  );
  return status.readyParcels;
}

/// Parcel count + ready parcels (with crop), for accurate empty-state copy.
Future<RecordLandStatus> loadRecordLandStatus(
  LocalStore store,
  String farmerId, {
  DateTime Function()? clock,
}) async {
  final parcels = await store.list(
    'parcels',
    where: (r) => r['farmer_id'] == farmerId && r['active'] != false,
  );
  parcels.sort(
    (a, b) =>
        '${a['created_at'] ?? '~'}'.compareTo('${b['created_at'] ?? '~'}'),
  );
  final ready = <CycleParcel>[];
  for (final parcel in parcels) {
    final cycle = await ensureActiveCycle(
      store,
      '${parcel['id']}',
      clock: clock,
    );
    if (cycle == null) continue;
    ready.add(
      CycleParcel(
        id: '${parcel['id']}',
        name: '${parcel['name']}',
        cropCycleId: cycle.cycleId,
        cropId: cycle.cropId,
        cropName: cycle.cropName,
      ),
    );
  }
  return RecordLandStatus(parcelCount: parcels.length, readyParcels: ready);
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
