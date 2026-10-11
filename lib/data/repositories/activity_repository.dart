import '../../domain/models/activity.dart';
import '../../domain/models/record_support.dart';
import '../../domain/models/sync_op.dart';
import '../../utils/result.dart';
import 'local_store.dart';
import 'record_lookups.dart';
import 'replica_watch.dart';

/// Reads and writes the farmer's farm activities through the local replica.
abstract class ActivityRepository {
  /// Farmer land ready for recording (parcel count + parcels with crop).
  Stream<RecordLandStatus> watchLandStatus();

  /// Synced catalogs of the flow (types, products, units...).
  Stream<ActivityCatalog> watchCatalog();

  /// Saves the activity (and its expense) on the device; the sync engine
  /// uploads them later. Returns the new activity id.
  Future<Result<String>> save(ActivityDraft draft);

  /// Every activity of the farmer, newest first.
  Stream<List<ActivitySummary>> watchActivities();

  /// Fertilization ("abono") activities only, newest first.
  Stream<List<ActivitySummary>> watchFertilizations();

  /// One activity; null when it does not exist.
  Stream<ActivityDetail?> watchActivity(String id);
}

class LocalActivityRepository implements ActivityRepository {
  LocalActivityRepository({
    required LocalStore store,
    required String farmerId,
    required String userId,
    DateTime Function()? clock,
  }) : _store = store,
       _farmerId = farmerId,
       _userId = userId,
       _clock = clock ?? DateTime.now;

  static const fertilizationCode = 'fertilization';

  static const _readTables = [
    'activities',
    'expenses',
    'activity_types',
    'products',
    'pruning_types',
    'expense_categories',
    'units',
    ...cycleParcelTables,
  ];

  final LocalStore _store;
  final String _farmerId;

  /// `profiles.id` of the signed-in farmer (`created_by` of every row).
  final String _userId;
  final DateTime Function() _clock;

  @override
  Stream<RecordLandStatus> watchLandStatus() => watchDerived(
    _store,
    cycleParcelTables,
    () => loadRecordLandStatus(_store, _farmerId, clock: _clock),
  );

  @override
  Stream<ActivityCatalog> watchCatalog() => watchDerived(_store, const [
    'activity_types',
    'products',
    'pruning_types',
    'expense_categories',
    'units',
    'activity_type_units',
    'product_units',
  ], _loadCatalog);

  Future<ActivityCatalog> _loadCatalog() async {
    final typeRows = await loadCatalogRows(_store, 'activity_types');
    return ActivityCatalog(
      types: [
        for (final r in typeRows)
          ActivityTypeOption(
            id: '${r['id']}',
            code: '${r['code']}',
            name: '${r['name']}',
            requiresProduct: r['requires_product'] == true,
            requiresPruningType: r['requires_pruning_type'] == true,
          ),
      ],
      products: await loadOptions(_store, 'products'),
      pruningTypes: await loadOptions(_store, 'pruning_types'),
      expenseCategories: await loadOptions(_store, 'expense_categories'),
      units: await loadUnits(_store),
      typeUnitIds: await loadUnitBridge(
        _store,
        'activity_type_units',
        'activity_type_id',
      ),
      productUnitIds: await loadUnitBridge(
        _store,
        'product_units',
        'product_id',
      ),
    );
  }

  @override
  Future<Result<String>> save(ActivityDraft draft) async {
    try {
      final quantity = draft.quantity;
      if (quantity != null && (quantity <= 0 || draft.unitId == null)) {
        return const Result.error(
          RecordException(RecordFailure.invalidNumber),
        );
      }
      final amount = draft.expenseAmount;
      if (amount != null && (amount <= 0 || draft.expenseCategoryId == null)) {
        return const Result.error(
          RecordException(RecordFailure.invalidNumber),
        );
      }
      final parcel = await _store.get('parcels', draft.parcel.id);
      if (parcel == null || parcel['farmer_id'] != _farmerId) {
        return const Result.error(RecordException(RecordFailure.noCycle));
      }

      final now = _clock();
      final today = dateOnly(now);
      final activityId = _store.newId();
      // Parent first, child after: the outbox keeps this order.
      await _store.save(
        table: 'activities',
        id: activityId,
        op: SyncOp.batch,
        row: {
          'crop_cycle_id': draft.parcel.cropCycleId,
          'activity_type_id': draft.typeId,
          'activity_date': today,
          'quantity': ?quantity,
          'unit_id': ?(quantity == null ? null : draft.unitId),
          'product_id': ?draft.productId,
          'pruning_type_id': ?draft.pruningTypeId,
          'created_by': _userId,
        },
      );
      if (amount != null) {
        await _store.save(
          table: 'expenses',
          id: _store.newId(),
          op: SyncOp.batch,
          row: {
            'crop_cycle_id': draft.parcel.cropCycleId,
            'parcel_id': draft.parcel.id,
            'category_id': draft.expenseCategoryId,
            'expense_date': today,
            'cost': amount,
            'currency': 'PEN',
            'activity_id': activityId,
            'created_by': _userId,
          },
        );
      }
      return Result.ok(activityId);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  @override
  Stream<List<ActivitySummary>> watchActivities() =>
      watchDerived(_store, _readTables, _loadSummaries);

  @override
  Stream<List<ActivitySummary>> watchFertilizations() =>
      watchDerived(_store, _readTables, _loadFertilizations);

  @override
  Stream<ActivityDetail?> watchActivity(String id) =>
      watchDerived(_store, _readTables, () => _loadDetail(id));

  Future<List<ActivitySummary>> _loadSummaries() async {
    final cycleToParcel = await _ownCycleParcels();
    final rows = await _store.list(
      'activities',
      where: (r) => cycleToParcel.containsKey(r['crop_cycle_id']),
    );
    return _summariesFor(rows, cycleToParcel);
  }

  Future<List<ActivitySummary>> _loadFertilizations() async {
    final cycleToParcel = await _ownCycleParcels();
    final typeIds = {
      for (final t in await _store.list(
        'activity_types',
        where: (r) => r['code'] == fertilizationCode,
      ))
        t['id'],
    };
    final rows = await _store.list(
      'activities',
      where: (r) =>
          cycleToParcel.containsKey(r['crop_cycle_id']) &&
          typeIds.contains(r['activity_type_id']),
    );
    return _summariesFor(rows, cycleToParcel);
  }

  Future<List<ActivitySummary>> _summariesFor(
    List<Map<String, dynamic>> rows,
    Map<String, String> cycleToParcel,
  ) async {
    rows.sort((a, b) {
      final byDate = '${b['activity_date'] ?? ''}'.compareTo(
        '${a['activity_date'] ?? ''}',
      );
      return byDate != 0
          ? byDate
          : '${b['created_at'] ?? b['client_created_at'] ?? '~'}'.compareTo(
              '${a['created_at'] ?? a['client_created_at'] ?? '~'}',
            );
    });
    final units = await loadUnitMap(_store);
    return [
      for (final row in rows) await _summary(row, cycleToParcel, units),
    ];
  }

  Future<ActivityDetail?> _loadDetail(String id) async {
    final row = await _store.get('activities', id);
    if (row == null || row['deleted_at'] != null) return null;
    final cycleToParcel = await _ownCycleParcels();
    final parcel = cycleToParcel['${row['crop_cycle_id']}'];
    if (parcel == null) return null;
    final units = await loadUnitMap(_store);
    final cycle = await _store.get('crop_cycles', '${row['crop_cycle_id']}');
    final crop = await _store.get('crops', '${cycle?['crop_id']}');
    final product = row['product_id'] == null
        ? null
        : await _store.get('products', '${row['product_id']}');
    final pruning = row['pruning_type_id'] == null
        ? null
        : await _store.get('pruning_types', '${row['pruning_type_id']}');
    final expense = await _expenseOf(id);
    final category = expense == null
        ? null
        : await _store.get('expense_categories', '${expense['category_id']}');
    return ActivityDetail(
      summary: await _summary(row, cycleToParcel, units),
      cropName: nonEmptyText(crop?['name']),
      productName: nonEmptyText(product?['name']),
      pruningTypeName: nonEmptyText(pruning?['name']),
      expenseCategoryName: nonEmptyText(category?['name']),
      notes: nonEmptyText(row['notes']),
    );
  }

  Future<ActivitySummary> _summary(
    Map<String, dynamic> row,
    Map<String, String> cycleToParcel,
    Map<String, UnitOption> units,
  ) async {
    final type = await _store.get('activity_types', '${row['activity_type_id']}');
    final expense = await _expenseOf('${row['id']}');
    return ActivitySummary(
      id: '${row['id']}',
      typeName: nonEmptyText(type?['name']) ?? 'Actividad',
      parcelName: cycleToParcel['${row['crop_cycle_id']}'] ?? 'Mi parcela',
      date: parseDate(row['activity_date']),
      quantityLabel: quantityLabel(
        row['quantity'],
        row['unit_id'],
        units,
        customUnit: row['custom_unit_label'],
      ),
      expenseAmount: toDouble(expense?['cost']),
      isPending:
          await _store.isPending('activities', '${row['id']}') ||
          (expense != null &&
              await _store.isPending('expenses', '${expense['id']}')),
    );
  }

  Future<Map<String, dynamic>?> _expenseOf(String activityId) async {
    final rows = await _store.list(
      'expenses',
      where: (r) => r['activity_id'] == activityId,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Crop cycle id -> parcel name, for the farmer's own parcels.
  Future<Map<String, String>> _ownCycleParcels() async {
    final parcels = {
      for (final p in await _store.list(
        'parcels',
        where: (r) => r['farmer_id'] == _farmerId,
      ))
        '${p['id']}': '${p['name']}',
    };
    final cycles = await _store.list(
      'crop_cycles',
      where: (r) => parcels.containsKey(r['parcel_id']),
    );
    return {for (final c in cycles) '${c['id']}': parcels['${c['parcel_id']}']!};
  }
}
