import '../../domain/models/harvest.dart';
import '../../domain/models/record_support.dart';
import '../../domain/models/sync_op.dart';
import '../../utils/result.dart';
import 'local_store.dart';
import 'record_lookups.dart';
import 'replica_watch.dart';

/// Reads and writes the farmer's harvests (with sales and residue).
abstract class HarvestRepository {
  /// Farmer land ready for recording (parcel count + parcels with crop).
  Stream<RecordLandStatus> watchLandStatus();

  /// Buyers and harvest units from the synced catalogs.
  Stream<HarvestCatalog> watchCatalog();

  /// Saves the harvest, its optional sale and residue on the device; the sync
  /// engine uploads them later. Returns the new harvest id.
  Future<Result<String>> save(HarvestDraft draft);

  /// Every harvest of the farmer, newest first.
  Stream<List<HarvestSummary>> watchHarvests();
}

class LocalHarvestRepository implements HarvestRepository {
  LocalHarvestRepository({
    required LocalStore store,
    required String farmerId,
    DateTime Function()? clock,
  }) : _store = store,
       _farmerId = farmerId,
       _clock = clock ?? DateTime.now;

  static const _readTables = [
    'harvests',
    'surplus_sales',
    'residue_management',
    'units',
    ...cycleParcelTables,
  ];

  final LocalStore _store;
  final String _farmerId;
  final DateTime Function() _clock;

  @override
  Stream<RecordLandStatus> watchLandStatus() => watchDerived(
    _store,
    cycleParcelTables,
    () => loadRecordLandStatus(_store, _farmerId, clock: _clock),
  );

  @override
  Stream<HarvestCatalog> watchCatalog() => watchDerived(_store, const [
    'buyers',
    'units',
    'crop_harvest_units',
  ], () async {
    return HarvestCatalog(
      buyers: await loadOptions(_store, 'buyers'),
      units: await loadUnits(_store),
      cropUnitIds: await loadUnitBridge(
        _store,
        'crop_harvest_units',
        'crop_id',
      ),
    );
  });

  @override
  Future<Result<String>> save(HarvestDraft draft) async {
    try {
      final total = draft.quantity;
      if (total <= 0) {
        return const Result.error(
          RecordException(RecordFailure.invalidNumber),
        );
      }
      final double? household;
      final double? surplus;
      switch (draft.destination) {
        case HarvestDestination.family:
          household = total;
          surplus = null;
        case HarvestDestination.surplus:
          household = null;
          surplus = total;
        case HarvestDestination.split:
          final part = draft.householdQuantity;
          if (part == null || part <= 0 || part >= total) {
            return const Result.error(
              RecordException(RecordFailure.invalidNumber),
            );
          }
          household = part;
          surplus = _round(total - part);
        case HarvestDestination.other:
          household = null;
          surplus = null;
      }
      final parcel = await _store.get('parcels', draft.parcel.id);
      if (parcel == null || parcel['farmer_id'] != _farmerId) {
        return const Result.error(RecordException(RecordFailure.noCycle));
      }

      final today = dateOnly(_clock());
      final harvestId = _store.newId();
      // Parent first, children after: the outbox keeps this order.
      await _store.save(
        table: 'harvests',
        id: harvestId,
        op: SyncOp.batch,
        row: {
          'crop_cycle_id': draft.parcel.cropCycleId,
          'parcel_id': draft.parcel.id,
          'harvest_date': today,
          'total_quantity': total,
          'total_unit_id': draft.unitId,
          'household_quantity': ?household,
          'surplus_quantity': ?surplus,
        },
      );

      final sale = draft.sale;
      if (sale != null && surplus != null && surplus > 0) {
        final price = sale.pricePerUnit;
        await _store.save(
          table: 'surplus_sales',
          id: _store.newId(),
          op: SyncOp.batch,
          row: {
            'harvest_id': harvestId,
            'quantity': surplus,
            'unit_id': draft.unitId,
            'price': ?price,
            // The price is per harvest unit.
            'price_unit_id': draft.unitId,
            'total_value': ?(price == null ? null : _round(price * surplus)),
            'buyer_id': ?sale.buyerId,
            'sale_date': today,
          },
        );
      }

      final residue = draft.residue;
      if (residue != null) {
        final quantity = residue.quantity;
        await _store.save(
          table: 'residue_management',
          id: _store.newId(),
          op: SyncOp.batch,
          row: {
            'harvest_id': harvestId,
            'residue_type': 'rastrojo',
            'quantity': ?quantity,
            'unit_id': ?(quantity == null ? null : residue.unitId),
            'destination': residue.use.wire,
          },
        );
      }
      return Result.ok(harvestId);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  @override
  Stream<List<HarvestSummary>> watchHarvests() =>
      watchDerived(_store, _readTables, _loadSummaries);

  Future<List<HarvestSummary>> _loadSummaries() async {
    final parcels = {
      for (final p in await _store.list(
        'parcels',
        where: (r) => r['farmer_id'] == _farmerId,
      ))
        '${p['id']}': '${p['name']}',
    };
    final rows = await _store.list(
      'harvests',
      where: (r) => parcels.containsKey(r['parcel_id']),
    );
    rows.sort((a, b) {
      final byDate = '${b['harvest_date'] ?? ''}'.compareTo(
        '${a['harvest_date'] ?? ''}',
      );
      return byDate != 0
          ? byDate
          : '${b['created_at'] ?? b['client_created_at'] ?? '~'}'.compareTo(
              '${a['created_at'] ?? a['client_created_at'] ?? '~'}',
            );
    });
    final units = await loadUnitMap(_store);
    final summaries = <HarvestSummary>[];
    for (final row in rows) {
      final id = '${row['id']}';
      final cycle = await _store.get('crop_cycles', '${row['crop_cycle_id']}');
      final crop = await _store.get('crops', '${cycle?['crop_id']}');
      final sales = await _store.list(
        'surplus_sales',
        where: (r) => r['harvest_id'] == id,
      );
      final residues = await _store.list(
        'residue_management',
        where: (r) => r['harvest_id'] == id,
      );
      final unitId = row['total_unit_id'];
      final saleTotals = [
        for (final s in sales) ?toDouble(s['total_value']),
      ];
      var pending = await _store.isPending('harvests', id);
      for (final s in sales) {
        pending = pending || await _store.isPending('surplus_sales', '${s['id']}');
      }
      for (final r in residues) {
        pending =
            pending || await _store.isPending('residue_management', '${r['id']}');
      }
      summaries.add(
        HarvestSummary(
          id: id,
          parcelName: parcels['${row['parcel_id']}'] ?? 'Mi parcela',
          cropName: nonEmptyText(crop?['name']) ?? 'Cultivo',
          date: parseDate(row['harvest_date']),
          quantityLabel:
              quantityLabel(row['total_quantity'], unitId, units) ?? '-',
          householdLabel: quantityLabel(row['household_quantity'], unitId, units),
          surplusLabel: quantityLabel(row['surplus_quantity'], unitId, units),
          saleTotal: saleTotals.isEmpty
              ? null
              : saleTotals.reduce((a, b) => a + b),
          residueLabel: residues.isEmpty
              ? null
              : _residueName('${residues.first['destination']}'),
          isPending: pending,
        ),
      );
    }
    return summaries;
  }

  static String _residueName(String wire) => switch (wire) {
    'compost' => 'Compost',
    'other_use' => 'Otro uso',
    'not_used' => 'No se usó',
    _ => 'Registrado',
  };

  static double _round(double value) => (value * 1e6).roundToDouble() / 1e6;
}
