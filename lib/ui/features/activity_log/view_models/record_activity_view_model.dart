import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/activity_repository.dart';
import '../../../../domain/models/activity.dart';
import '../../../../domain/models/record_support.dart';
import '../../../../utils/result.dart';

enum ActivityStep {
  parcel,
  type,
  product,
  pruning,
  quantity,
  expenseAmount,
  expenseCategory,
  confirm,
}

/// State of the one-question-per-screen "Registrar actividad" flow.
///
/// The questions that apply depend on the answers: the product only for
/// activity types that need one, units only when the catalog allows some.
class RecordActivityViewModel extends ChangeNotifier {
  RecordActivityViewModel({required ActivityRepository repository})
    : _repository = repository {
    _subscriptions = [
      repository.watchLandStatus().listen((land) {
        _parcelCount = land.parcelCount;
        _parcels = land.readyParcels;
        _parcelsLoaded = true;
        if (_parcels.length == 1) _parcelId = _parcels.first.id;
        if (_parcelId != null && !_parcels.any((p) => p.id == _parcelId)) {
          _parcelId = null;
        }
        notifyListeners();
      }, onError: (_) => _markLoaded()),
      repository.watchCatalog().listen((catalog) {
        _catalog = catalog;
        _catalogLoaded = true;
        notifyListeners();
      }, onError: (_) => _markLoaded()),
    ];
  }

  final ActivityRepository _repository;
  late final List<StreamSubscription<Object?>> _subscriptions;
  bool _disposed = false;

  int _parcelCount = 0;
  List<CycleParcel> _parcels = const [];
  ActivityCatalog _catalog = const ActivityCatalog();
  bool _parcelsLoaded = false;
  bool _catalogLoaded = false;

  ActivityStep? _current;
  String? _parcelId;
  String? _typeId;
  String? _productId;
  String? _pruningTypeId;
  String _quantityText = '';
  String? _unitId;
  String _amountText = '';
  String? _expenseCategoryId;
  bool _isSaving = false;
  String? _savedId;
  String? _errorMessage;

  List<CycleParcel> get parcels => _parcels;
  ActivityCatalog get catalog => _catalog;
  bool get isLoading => !_parcelsLoaded || !_catalogLoaded;

  /// No land at all in "Mi parcela".
  bool get hasNoParcel => _parcelsLoaded && _parcelCount == 0;

  /// Has land, but no crop cycle is ready yet (catalog/sync still missing).
  bool get needsCrop => _parcelsLoaded && _parcelCount > 0 && _parcels.isEmpty;

  bool get hasNoCatalog => _catalog.types.isEmpty;

  bool get isBlocked => hasNoParcel || needsCrop || hasNoCatalog;

  String? get parcelId => _parcelId;
  String? get typeId => _typeId;
  String? get productId => _productId;
  String? get pruningTypeId => _pruningTypeId;
  String get quantityText => _quantityText;
  String get amountText => _amountText;
  String? get expenseCategoryId => _expenseCategoryId;
  bool get isSaving => _isSaving;
  String? get savedId => _savedId;
  String? get errorMessage => _errorMessage;

  CycleParcel? get selectedParcel {
    for (final parcel in _parcels) {
      if (parcel.id == _parcelId) return parcel;
    }
    return null;
  }

  ActivityTypeOption? get selectedType {
    for (final type in _catalog.types) {
      if (type.id == _typeId) return type;
    }
    return null;
  }

  CatalogOption? get selectedProduct => _find(_catalog.products, _productId);
  CatalogOption? get selectedPruningType =>
      _find(_catalog.pruningTypes, _pruningTypeId);
  CatalogOption? get selectedExpenseCategory =>
      _find(_catalog.expenseCategories, _expenseCategoryId);

  /// Units allowed for the chosen type (and product); empty skips the
  /// quantity question.
  List<UnitOption> get allowedUnits {
    final typeId = _typeId;
    if (typeId == null) return const [];
    return _catalog.unitsFor(typeId, productId: _productId);
  }

  /// The chosen unit, or the first allowed one.
  UnitOption? get selectedUnit {
    final units = allowedUnits;
    for (final unit in units) {
      if (unit.id == _unitId) return unit;
    }
    return units.isEmpty ? null : units.first;
  }

  double? get quantity => parseDecimal(_quantityText);
  double? get expenseAmount => parseDecimal(_amountText);
  bool get spentMoney => (expenseAmount ?? 0) > 0;

  List<ActivityStep> get path {
    final type = selectedType;
    return [
      if (_parcels.length > 1) ActivityStep.parcel,
      ActivityStep.type,
      if (type != null && type.requiresProduct) ActivityStep.product,
      if (type != null && type.requiresPruningType) ActivityStep.pruning,
      if (allowedUnits.isNotEmpty) ActivityStep.quantity,
      ActivityStep.expenseAmount,
      if (spentMoney) ActivityStep.expenseCategory,
      ActivityStep.confirm,
    ];
  }

  ActivityStep get step {
    final steps = path;
    final current = _current;
    return current != null && steps.contains(current) ? current : steps.first;
  }

  bool get isAtFirstStep => path.first == step;
  bool get isAtLastStep => step == ActivityStep.confirm;

  bool get canContinue => switch (step) {
    ActivityStep.parcel => _parcelId != null,
    ActivityStep.type => _typeId != null,
    ActivityStep.product => _productId != null,
    ActivityStep.pruning => _pruningTypeId != null,
    ActivityStep.quantity =>
      _quantityText.trim().isEmpty || (quantity ?? 0) > 0,
    ActivityStep.expenseAmount =>
      _amountText.trim().isEmpty || (expenseAmount ?? 0) > 0,
    ActivityStep.expenseCategory => _expenseCategoryId != null,
    ActivityStep.confirm => !_isSaving && _parcelId != null,
  };

  void selectParcel(String id) => _change(() => _parcelId = id);

  void selectType(String id) => _change(() {
    _typeId = id;
    _productId = null;
    _pruningTypeId = null;
    _unitId = null;
  });

  void selectProduct(String id) => _change(() {
    _productId = id;
    _unitId = null;
  });

  void selectPruningType(String id) => _change(() => _pruningTypeId = id);
  void selectUnit(String id) => _change(() => _unitId = id);
  void selectExpenseCategory(String id) =>
      _change(() => _expenseCategoryId = id);

  void setQuantity(String value) {
    _quantityText = value;
    notifyListeners();
  }

  void setAmount(String value) {
    _amountText = value;
    if (!spentMoney) _expenseCategoryId = null;
    notifyListeners();
  }

  /// Moves to the next question; no-op when it cannot continue.
  void next() {
    if (!canContinue || isAtLastStep) return;
    final steps = path;
    _current = steps[steps.indexOf(step) + 1];
    _errorMessage = null;
    notifyListeners();
  }

  /// Goes back one question. Returns false when already at the first one.
  bool back() {
    if (isAtFirstStep || _isSaving) return false;
    final steps = path;
    _current = steps[steps.indexOf(step) - 1];
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Saves the activity on the device. Returns true on success.
  Future<bool> submit() async {
    final parcel = selectedParcel;
    final typeId = _typeId;
    if (parcel == null || typeId == null || _isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final unit = selectedUnit;
    final hasQuantity = unit != null && (quantity ?? 0) > 0;
    final result = await _repository.save(
      ActivityDraft(
        parcel: parcel,
        typeId: typeId,
        productId: selectedType?.requiresProduct == true ? _productId : null,
        pruningTypeId: selectedType?.requiresPruningType == true
            ? _pruningTypeId
            : null,
        quantity: hasQuantity ? quantity : null,
        unitId: hasQuantity ? unit.id : null,
        expenseAmount: spentMoney ? expenseAmount : null,
        expenseCategoryId: spentMoney ? _expenseCategoryId : null,
      ),
    );
    _isSaving = false;
    switch (result) {
      case Ok(:final value):
        _savedId = value;
      case Error(:final error):
        _errorMessage = _messageFor(error);
    }
    if (!_disposed) notifyListeners();
    return _savedId != null;
  }

  void _change(VoidCallback update) {
    update();
    notifyListeners();
  }

  static CatalogOption? _find(List<CatalogOption> options, String? id) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  static String _messageFor(Exception error) {
    if (error is RecordException) {
      return switch (error.failure) {
        RecordFailure.noCycle =>
          'No encontramos su parcela. Vuelva a "Mi parcela" e intente de nuevo',
        RecordFailure.invalidNumber => 'Revise la cantidad y el monto',
        RecordFailure.missingChoice => 'Falta elegir una opción',
        RecordFailure.storage => 'No se pudo guardar en el teléfono',
      };
    }
    return 'No se pudo guardar. Intente otra vez';
  }

  void _markLoaded() {
    _parcelsLoaded = true;
    _catalogLoaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
