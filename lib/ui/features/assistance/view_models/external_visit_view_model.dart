import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/assistance_repository.dart';
import '../../../../data/services/photo_service.dart';
import '../../../../domain/models/assistance.dart';
import '../../../../domain/models/incident.dart';
import '../../../../domain/models/record_support.dart';
import '../../../../utils/result.dart';

enum ExternalVisitStep {
  parcel,
  provider,
  institution,
  date,
  category,
  photos,
  comment,
  confirm,
}

/// State of the "Registrar visita externa" flow: a visit from SENASA or
/// another institution, with a photo of the document (no OCR).
class ExternalVisitViewModel extends ChangeNotifier {
  ExternalVisitViewModel({
    required AssistanceRepository repository,
    required PhotoService photoService,
    DateTime Function()? clock,
  }) : _repository = repository,
       _photoService = photoService,
       _clock = clock ?? DateTime.now {
    _date = _clock();
    _subscription = repository.watchCatalog().listen(
      (catalog) {
        _catalog = catalog;
        _loaded = true;
        final parcels = catalog.parcels;
        if (parcels.length == 1) _parcelId = parcels.first.id;
        if (_parcelId != null && !parcels.any((p) => p.id == _parcelId)) {
          _parcelId = null;
        }
        notifyListeners();
      },
      onError: (_) {
        _loaded = true;
        notifyListeners();
      },
    );
  }

  final AssistanceRepository _repository;
  final PhotoService _photoService;
  final DateTime Function() _clock;
  late final StreamSubscription<ExternalVisitCatalog> _subscription;
  bool _disposed = false;

  ExternalVisitCatalog _catalog = const ExternalVisitCatalog();
  bool _loaded = false;

  ExternalVisitStep? _current;
  String? _parcelId;
  AssistanceProvider? _provider;
  String _institution = '';
  late DateTime _date;
  String? _categoryId;
  final List<PickedPhoto> _photos = [];
  String _comment = '';
  bool _isSaving = false;
  bool _isPickingPhoto = false;
  String? _savedId;
  String? _errorMessage;

  ExternalVisitCatalog get catalog => _catalog;
  bool get isLoading => !_loaded;
  bool get hasNoParcel => _catalog.parcels.isEmpty;
  bool get hasNoCategories => _catalog.categories.isEmpty;
  String? get parcelId => _parcelId;
  AssistanceProvider? get provider => _provider;
  String get institution => _institution;
  DateTime get date => _date;
  String? get categoryId => _categoryId;
  String get comment => _comment;
  List<PickedPhoto> get photos => List.unmodifiable(_photos);
  bool get canAddPhoto => _photos.length < ExternalVisitDraft.maxPhotos;
  bool get isSaving => _isSaving;
  bool get isPickingPhoto => _isPickingPhoto;
  String? get savedId => _savedId;
  String? get errorMessage => _errorMessage;

  IncidentParcel? get selectedParcel {
    for (final parcel in _catalog.parcels) {
      if (parcel.id == _parcelId) return parcel;
    }
    return null;
  }

  CatalogOption? get selectedCategory {
    for (final category in _catalog.categories) {
      if (category.id == _categoryId) return category;
    }
    return null;
  }

  List<ExternalVisitStep> get path => [
    if (_catalog.parcels.length > 1) ExternalVisitStep.parcel,
    ExternalVisitStep.provider,
    if (_provider == AssistanceProvider.other) ExternalVisitStep.institution,
    ExternalVisitStep.date,
    ExternalVisitStep.category,
    ExternalVisitStep.photos,
    ExternalVisitStep.comment,
    ExternalVisitStep.confirm,
  ];

  ExternalVisitStep get step {
    final steps = path;
    final current = _current;
    return current != null && steps.contains(current) ? current : steps.first;
  }

  bool get isAtFirstStep => path.first == step;
  bool get isAtLastStep => step == ExternalVisitStep.confirm;

  bool get canContinue => switch (step) {
    ExternalVisitStep.parcel => _parcelId != null,
    ExternalVisitStep.provider => _provider != null,
    ExternalVisitStep.institution => _institution.trim().isNotEmpty,
    ExternalVisitStep.date => true,
    ExternalVisitStep.category => _categoryId != null,
    ExternalVisitStep.photos => !_isPickingPhoto,
    ExternalVisitStep.comment => true,
    ExternalVisitStep.confirm => !_isSaving && _parcelId != null,
  };

  void selectParcel(String id) => _change(() => _parcelId = id);
  void selectProvider(AssistanceProvider value) => _change(() {
    _provider = value;
    if (value != AssistanceProvider.other) _institution = '';
  });
  void selectCategory(String id) => _change(() => _categoryId = id);

  /// Dates are limited to today or earlier: it records a visit that happened.
  void setDate(DateTime value) {
    final today = _clock();
    _date = value.isAfter(today) ? today : value;
    notifyListeners();
  }

  void setInstitution(String value) {
    _institution = value;
    notifyListeners();
  }

  void setComment(String value) {
    _comment = value;
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

  Future<void> addPhoto(PhotoSource source) async {
    if (!canAddPhoto || _isPickingPhoto) return;
    _isPickingPhoto = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final photo = await _photoService.pick(source);
      if (photo != null) _photos.add(photo);
    } on Object {
      _errorMessage =
          'No pudimos abrir la cámara o la galería. Revise los permisos del teléfono';
    }
    _isPickingPhoto = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> removePhoto(PickedPhoto photo) async {
    if (!_photos.remove(photo)) return;
    notifyListeners();
    await _photoService.discard(photo.localPath);
  }

  /// Saves the visit on the device. Returns true on success.
  Future<bool> submit() async {
    final parcelId = _parcelId;
    final provider = _provider;
    final categoryId = _categoryId;
    if (parcelId == null ||
        provider == null ||
        categoryId == null ||
        _isSaving) {
      return false;
    }
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.saveExternalVisit(
      ExternalVisitDraft(
        parcelId: parcelId,
        provider: provider,
        institutionName: _institution,
        date: _date,
        categoryId: categoryId,
        comment: _comment,
        photos: List.of(_photos),
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

  static String _messageFor(Exception error) {
    if (error is RecordException) {
      return switch (error.failure) {
        RecordFailure.noCycle => 'Elija la parcela de la visita',
        RecordFailure.invalidNumber => 'Revise los datos',
        RecordFailure.missingChoice => 'Falta elegir una opción',
        RecordFailure.storage => 'No se pudo guardar en el teléfono',
      };
    }
    return 'No se pudo guardar. Intente otra vez';
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    if (_savedId == null) {
      // Nothing was saved: drop the photo copies made for this draft.
      for (final photo in _photos) {
        unawaited(_photoService.discard(photo.localPath));
      }
    }
    super.dispose();
  }
}
