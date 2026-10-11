import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/incident_repository.dart';
import '../../../../data/services/photo_service.dart';
import '../../../../domain/models/incident.dart';
import '../../../../utils/result.dart';

enum ReportStep { parcel, symptoms, description, photos, confirm }

/// State of the one-question-per-screen "Reportar problema" flow.
class ReportIncidentViewModel extends ChangeNotifier {
  ReportIncidentViewModel({
    required IncidentRepository repository,
    required PhotoService photoService,
  }) : _repository = repository,
       _photoService = photoService {
    _subscriptions = [
      repository.watchParcels().listen((parcels) {
        _parcels = parcels;
        _parcelsLoaded = true;
        if (parcels.length == 1) _parcelId = parcels.first.id;
        if (_parcelId != null && !parcels.any((p) => p.id == _parcelId)) {
          _parcelId = null;
        }
        // A single parcel makes the first question unnecessary.
        if (parcels.length == 1 && _step == ReportStep.parcel) {
          _step = ReportStep.symptoms;
        }
        notifyListeners();
      }, onError: (_) => _markLoaded()),
      repository.watchSymptoms().listen((symptoms) {
        _symptoms = symptoms;
        _symptomsLoaded = true;
        notifyListeners();
      }, onError: (_) => _markLoaded()),
    ];
  }

  final IncidentRepository _repository;
  final PhotoService _photoService;
  late final List<StreamSubscription<Object?>> _subscriptions;
  bool _disposed = false;

  List<IncidentParcel> _parcels = const [];
  List<SymptomType> _symptoms = const [];
  bool _parcelsLoaded = false;
  bool _symptomsLoaded = false;
  String? _parcelId;
  final List<String> _symptomIds = [];
  String _description = '';
  final List<PickedPhoto> _photos = [];
  ReportStep _step = ReportStep.parcel;
  bool _isSaving = false;
  bool _isPickingPhoto = false;
  String? _savedId;
  String? _errorMessage;

  List<IncidentParcel> get parcels => _parcels;
  List<SymptomType> get symptoms => _symptoms;
  bool get isLoading => !_parcelsLoaded || !_symptomsLoaded;
  String? get parcelId => _parcelId;
  Set<String> get selectedSymptomIds => _symptomIds.toSet();
  String get description => _description;
  List<PickedPhoto> get photos => List.unmodifiable(_photos);
  bool get canAddPhoto => _photos.length < IncidentDraft.maxPhotos;
  ReportStep get step => _step;
  bool get isSaving => _isSaving;
  bool get isPickingPhoto => _isPickingPhoto;
  String? get savedId => _savedId;
  String? get errorMessage => _errorMessage;

  /// With a single parcel the question is skipped.
  bool get skipsParcelStep => _parcels.length == 1;

  IncidentParcel? get selectedParcel {
    for (final parcel in _parcels) {
      if (parcel.id == _parcelId) return parcel;
    }
    return null;
  }

  List<SymptomType> get selectedSymptoms => [
    for (final id in _symptomIds)
      for (final symptom in _symptoms)
        if (symptom.id == id) symptom,
  ];

  bool get isAtFirstStep =>
      _step == ReportStep.parcel ||
      (_step == ReportStep.symptoms && skipsParcelStep);

  bool get canContinue => switch (_step) {
    ReportStep.parcel => _parcelId != null,
    ReportStep.symptoms => _symptomIds.isNotEmpty,
    ReportStep.description => true,
    ReportStep.photos => !_isPickingPhoto,
    ReportStep.confirm => !_isSaving,
  };

  void selectParcel(String id) {
    _parcelId = id;
    notifyListeners();
  }

  void toggleSymptom(String id) {
    if (!_symptomIds.remove(id)) _symptomIds.add(id);
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value;
  }

  /// Moves to the next question; no-op when it cannot continue.
  void next() {
    if (!canContinue) return;
    _step = switch (_step) {
      ReportStep.parcel => ReportStep.symptoms,
      ReportStep.symptoms => ReportStep.description,
      ReportStep.description => ReportStep.photos,
      ReportStep.photos => ReportStep.confirm,
      ReportStep.confirm => ReportStep.confirm,
    };
    _errorMessage = null;
    notifyListeners();
  }

  /// Goes back one question. Returns false when already at the first one.
  bool back() {
    if (isAtFirstStep || _isSaving) return false;
    _step = switch (_step) {
      ReportStep.parcel => ReportStep.parcel,
      ReportStep.symptoms => ReportStep.parcel,
      ReportStep.description => ReportStep.symptoms,
      ReportStep.photos => ReportStep.description,
      ReportStep.confirm => ReportStep.photos,
    };
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

  /// Saves the report on the device. Returns true on success.
  Future<bool> submit() async {
    final parcelId = _parcelId;
    if (parcelId == null || _isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.submit(
      IncidentDraft(
        parcelId: parcelId,
        symptoms: selectedSymptoms,
        description: _description,
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

  static String _messageFor(Exception error) {
    if (error is IncidentException) {
      return switch (error.failure) {
        IncidentFailure.noCrop =>
          'Su parcela todavía no tiene un cultivo registrado. Hable con su técnico',
        IncidentFailure.noParcel => 'Elija la parcela del problema',
        IncidentFailure.noSymptom => 'Elija al menos una señal',
        IncidentFailure.tooManyPhotos => 'Puede enviar hasta 3 fotos',
        IncidentFailure.storage => 'No se pudo guardar en el teléfono',
      };
    }
    return 'No se pudo guardar. Intente otra vez';
  }

  void _markLoaded() {
    _parcelsLoaded = true;
    _symptomsLoaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    if (_savedId == null) {
      // Nothing was saved: drop the photo copies made for this draft.
      for (final photo in _photos) {
        unawaited(_photoService.discard(photo.localPath));
      }
    }
    super.dispose();
  }
}
