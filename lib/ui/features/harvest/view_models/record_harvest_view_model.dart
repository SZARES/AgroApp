import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/harvest_repository.dart';
import '../../../../domain/models/harvest.dart';
import '../../../../domain/models/record_support.dart';
import '../../../../utils/result.dart';

enum HarvestStep { parcel, quantity, destination, split, sale, residue, confirm }

/// State of the one-question-per-screen "Registrar cosecha" flow.
class RecordHarvestViewModel extends ChangeNotifier {
  RecordHarvestViewModel({required HarvestRepository repository})
    : _repository = repository {
    _subscriptions = [
      repository.watchParcels().listen((parcels) {
        _parcels = parcels;
        _parcelsLoaded = true;
        if (parcels.length == 1) _parcelId = parcels.first.id;
        if (_parcelId != null && !parcels.any((p) => p.id == _parcelId)) {
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

  final HarvestRepository _repository;
  late final List<StreamSubscription<Object?>> _subscriptions;
  bool _disposed = false;

  List<CycleParcel> _parcels = const [];
  HarvestCatalog _catalog = const HarvestCatalog();
  bool _parcelsLoaded = false;
  bool _catalogLoaded = false;

  HarvestStep? _current;
  String? _parcelId;
  String _quantityText = '';
  String? _unitId;
  HarvestDestination? _destination;
  String _householdText = '';
  bool? _sold;
  String? _buyerId;
  String _priceText = '';
  ResidueUse? _residueUse;
  String _residueQuantityText = '';
  String? _residueUnitId;
  bool _isSaving = false;
  String? _savedId;
  String? _errorMessage;

  List<CycleParcel> get parcels => _parcels;
  HarvestCatalog get catalog => _catalog;
  bool get isLoading => !_parcelsLoaded || !_catalogLoaded;
  bool get hasNoParcel => _parcels.isEmpty;
  bool get hasNoUnits => _catalog.units.isEmpty;

  String? get parcelId => _parcelId;
  String get quantityText => _quantityText;
  HarvestDestination? get destination => _destination;
  String get householdText => _householdText;
  bool? get sold => _sold;
  String? get buyerId => _buyerId;
  String get priceText => _priceText;
  ResidueUse? get residueUse => _residueUse;
  String get residueQuantityText => _residueQuantityText;
  bool get isSaving => _isSaving;
  String? get savedId => _savedId;
  String? get errorMessage => _errorMessage;

  CycleParcel? get selectedParcel {
    for (final parcel in _parcels) {
      if (parcel.id == _parcelId) return parcel;
    }
    return null;
  }

  /// Harvest units of the parcel's crop.
  List<UnitOption> get units {
    final parcel = selectedParcel;
    return parcel == null ? const [] : _catalog.unitsForCrop(parcel.cropId);
  }

  UnitOption? get selectedUnit => _pick(units, _unitId);

  /// Unit of the residue quantity; defaults to the harvest unit.
  UnitOption? get selectedResidueUnit {
    for (final unit in units) {
      if (unit.id == _residueUnitId) return unit;
    }
    return selectedUnit;
  }

  CatalogOption? get selectedBuyer {
    for (final buyer in _catalog.buyers) {
      if (buyer.id == _buyerId) return buyer;
    }
    return null;
  }

  double? get quantity => parseDecimal(_quantityText);
  double? get householdQuantity => parseDecimal(_householdText);
  double? get pricePerUnit => parseDecimal(_priceText);
  double? get residueQuantity => parseDecimal(_residueQuantityText);

  bool get hasSurplus =>
      _destination == HarvestDestination.surplus ||
      _destination == HarvestDestination.split;

  /// Part of the harvest left to sell.
  double? get surplusQuantity {
    final total = quantity;
    if (total == null) return null;
    return switch (_destination) {
      HarvestDestination.surplus => total,
      HarvestDestination.split =>
        householdQuantity == null ? null : total - householdQuantity!,
      _ => null,
    };
  }

  List<HarvestStep> get path => [
    if (_parcels.length > 1) HarvestStep.parcel,
    HarvestStep.quantity,
    HarvestStep.destination,
    if (_destination == HarvestDestination.split) HarvestStep.split,
    if (hasSurplus) HarvestStep.sale,
    HarvestStep.residue,
    HarvestStep.confirm,
  ];

  HarvestStep get step {
    final steps = path;
    final current = _current;
    return current != null && steps.contains(current) ? current : steps.first;
  }

  bool get isAtFirstStep => path.first == step;
  bool get isAtLastStep => step == HarvestStep.confirm;

  bool get canContinue => switch (step) {
    HarvestStep.parcel => _parcelId != null,
    HarvestStep.quantity => (quantity ?? 0) > 0 && selectedUnit != null,
    HarvestStep.destination => _destination != null,
    HarvestStep.split =>
      (householdQuantity ?? 0) > 0 &&
          (quantity ?? 0) > 0 &&
          householdQuantity! < quantity!,
    HarvestStep.sale =>
      _sold != null &&
          (_sold == false ||
              _priceText.trim().isEmpty ||
              (pricePerUnit ?? 0) > 0),
    HarvestStep.residue =>
      _residueUse == null ||
          _residueQuantityText.trim().isEmpty ||
          (residueQuantity ?? 0) > 0,
    HarvestStep.confirm => !_isSaving && _parcelId != null,
  };

  void selectParcel(String id) => _change(() {
    _parcelId = id;
    _unitId = null;
    _residueUnitId = null;
  });

  void selectUnit(String id) => _change(() => _unitId = id);
  void selectDestination(HarvestDestination value) => _change(() {
    _destination = value;
    if (!hasSurplus) {
      _sold = null;
      _buyerId = null;
      _priceText = '';
    }
  });
  void selectSold(bool value) => _change(() => _sold = value);
  void selectBuyer(String? id) => _change(() => _buyerId = id);
  void selectResidueUnit(String id) => _change(() => _residueUnitId = id);

  /// Picking the same use twice clears it (the question is optional).
  void toggleResidue(ResidueUse use) =>
      _change(() => _residueUse = _residueUse == use ? null : use);

  void setQuantity(String value) {
    _quantityText = value;
    notifyListeners();
  }

  void setHousehold(String value) {
    _householdText = value;
    notifyListeners();
  }

  void setPrice(String value) {
    _priceText = value;
    notifyListeners();
  }

  void setResidueQuantity(String value) {
    _residueQuantityText = value;
    notifyListeners();
  }

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

  /// Saves the harvest on the device. Returns true on success.
  Future<bool> submit() async {
    final parcel = selectedParcel;
    final unit = selectedUnit;
    final total = quantity;
    final destination = _destination;
    if (parcel == null ||
        unit == null ||
        total == null ||
        destination == null ||
        _isSaving) {
      return false;
    }
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final residueUse = _residueUse;
    final residueQuantity = this.residueQuantity;
    final result = await _repository.save(
      HarvestDraft(
        parcel: parcel,
        quantity: total,
        unitId: unit.id,
        destination: destination,
        householdQuantity: destination == HarvestDestination.split
            ? householdQuantity
            : null,
        sale: hasSurplus && _sold == true
            ? SaleDraft(buyerId: _buyerId, pricePerUnit: pricePerUnit)
            : null,
        residue: residueUse == null
            ? null
            : ResidueDraft(
                use: residueUse,
                quantity: residueUse == ResidueUse.notUsed
                    ? null
                    : residueQuantity,
                unitId: residueUse == ResidueUse.notUsed
                    ? null
                    : selectedResidueUnit?.id,
              ),
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

  /// The chosen unit when it is allowed, else the first allowed one.
  static UnitOption? _pick(List<UnitOption> units, String? id) {
    for (final unit in units) {
      if (unit.id == id) return unit;
    }
    return units.isEmpty ? null : units.first;
  }

  static String _messageFor(Exception error) {
    if (error is RecordException) {
      return switch (error.failure) {
        RecordFailure.noCycle =>
          'Su parcela todavía no tiene un cultivo activo. Hable con su técnico',
        RecordFailure.invalidNumber => 'Revise las cantidades',
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
