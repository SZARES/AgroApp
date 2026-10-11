import '../../domain/models/geo_point.dart';
import '../../domain/models/incident_status.dart';
import '../../domain/models/parcel.dart';
import '../../domain/models/parcel_failure.dart';
import '../../domain/models/sync_op.dart';
import '../../utils/result.dart';
import 'local_store.dart';
import 'replica_watch.dart';

/// The farmer's parcels, read from and written to the local replica.
abstract class ParcelRepository {
  /// Live list of the farmer's parcels (soft-deleted ones excluded).
  Stream<List<Parcel>> watchParcels();

  /// Saves a new parcel locally with a client-generated id and queues it for
  /// upload.
  Future<Result<Parcel>> addParcel({
    required String name,
    required double areaHectares,
    GeoPoint? location,
  });
}

class LocalParcelRepository implements ParcelRepository {
  LocalParcelRepository({required LocalStore store, required String farmerId})
    : _store = store,
      _farmerId = farmerId;

  static const table = 'parcels';

  final LocalStore _store;
  final String _farmerId;

  @override
  Stream<List<Parcel>> watchParcels() => watchDerived(_store, const [
    table,
    'crop_cycles',
    'crops',
    'incidents',
  ], _load);

  Future<List<Parcel>> _load() async {
    final rows = await _ownRows();
    final cycles = await _store.list(
      'crop_cycles',
      where: (r) => r['status'] == 'active',
    );
    final crops = {
      for (final crop in await _store.list('crops')) crop['id']: crop['name'],
    };
    final incidents = await _store.list(
      'incidents',
      where: (r) =>
          r['farmer_id'] == _farmerId &&
          (IncidentStatus.tryParse(r['status'])?.isOpen ?? true),
    );

    final parcels = <Parcel>[];
    for (final row in rows) {
      final parcel = Parcel.tryFromRow(row);
      if (parcel == null) continue;
      final cycle = cycles.where((c) => c['parcel_id'] == parcel.id);
      final cropName = cycle.isEmpty ? null : crops[cycle.first['crop_id']];
      parcels.add(
        parcel.copyWith(
          cropName: cropName is String ? cropName : null,
          openIncidents: incidents
              .where((i) => i['parcel_id'] == parcel.id)
              .length,
          pendingSync: await _store.isPending(table, parcel.id),
        ),
      );
    }
    return List.unmodifiable(parcels);
  }

  Future<List<Map<String, dynamic>>> _ownRows() async {
    final rows = await _store.list(
      table,
      where: (r) => r['farmer_id'] == _farmerId && r['active'] != false,
    );
    rows.sort(
      (a, b) => '${a['created_at'] ?? '~'}${a['name']}'.compareTo(
        '${b['created_at'] ?? '~'}${b['name']}',
      ),
    );
    return rows;
  }

  @override
  Future<Result<Parcel>> addParcel({
    required String name,
    required double areaHectares,
    GeoPoint? location,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return const Result.error(ParcelFailure.invalidName);
    if (!areaHectares.isFinite || areaHectares <= 0) {
      return const Result.error(ParcelFailure.invalidArea);
    }
    try {
      final zoneId = await _zoneId();
      if (zoneId == null) return const Result.error(ParcelFailure.noZone);
      final hectare = (await _store.list(
        'units',
        where: (u) => u['abbreviation'] == 'ha',
      )).firstOrNull;

      final id = _store.newId();
      final row = <String, dynamic>{
        'farmer_id': _farmerId,
        'zone_id': zoneId,
        'name': cleanName,
        'area': areaHectares,
        'area_unit_id': ?hectare?['id'],
        if (location != null) ...{
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
        'active': true,
      };
      // `parcels` is not accepted by sync_batch, so it goes out as an upsert.
      await _store.save(table: table, id: id, row: row, op: SyncOp.upsert);
      final saved = Parcel.tryFromRow({...row, 'id': id});
      if (saved == null) return const Result.error(ParcelFailure.saveFailed);
      return Result.ok(saved.copyWith(pendingSync: true));
    } on Object {
      return const Result.error(ParcelFailure.saveFailed);
    }
  }

  /// Zone of the farmer's first parcel, else of the farmer's community.
  Future<String?> _zoneId() async {
    for (final row in await _ownRows()) {
      final zone = row['zone_id'];
      if (zone is String) return zone;
    }
    final farmer = await _store.get('farmers', _farmerId);
    final communityId = farmer?['community_id'];
    if (communityId is! String) return null;
    final community = await _store.get('communities', communityId);
    final zone = community?['zone_id'];
    return zone is String ? zone : null;
  }
}
