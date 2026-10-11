import 'package:flutter/foundation.dart';

import 'incident_status.dart';

/// A symptom the farmer can pick, from the synced `symptom_types` catalog.
@immutable
class SymptomType {
  const SymptomType({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is SymptomType && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// A parcel the farmer can report a problem on.
@immutable
class IncidentParcel {
  const IncidentParcel({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is IncidentParcel && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// A photo already compressed and copied into app storage.
@immutable
class PickedPhoto {
  const PickedPhoto({
    required this.localPath,
    required this.width,
    required this.height,
    required this.sizeBytes,
  });

  final String localPath;
  final int width;
  final int height;
  final int sizeBytes;
}

/// What the farmer entered in the report flow.
@immutable
class IncidentDraft {
  const IncidentDraft({
    required this.parcelId,
    required this.symptoms,
    this.description = '',
    this.photos = const [],
  });

  final String parcelId;

  /// At least one; the first one is stored as the main symptom.
  final List<SymptomType> symptoms;
  final String description;

  /// Zero to [maxPhotos] photos.
  final List<PickedPhoto> photos;

  static const maxPhotos = 3;
}

enum IncidentFailure { noParcel, noSymptom, noCrop, tooManyPhotos, storage }

class IncidentException implements Exception {
  const IncidentException(this.failure);

  final IncidentFailure failure;

  @override
  String toString() => 'IncidentException($failure)';
}

/// One row of "Mis reportes".
@immutable
class IncidentSummary {
  const IncidentSummary({
    required this.id,
    required this.symptom,
    required this.parcelName,
    required this.status,
    required this.reportedAt,
    required this.isPending,
  });

  final String id;
  final String symptom;
  final String parcelName;
  final IncidentStatus status;
  final DateTime? reportedAt;

  /// True while the report has not reached the server yet.
  final bool isPending;
}

@immutable
class IncidentPhotoInfo {
  const IncidentPhotoInfo({
    required this.id,
    required this.storagePath,
    this.localPath,
  });

  final String id;
  final String storagePath;

  /// File on this device, when it still exists.
  final String? localPath;
}

@immutable
class IncidentHistoryEntry {
  const IncidentHistoryEntry({
    required this.status,
    required this.changedAt,
    this.changedByName,
    this.comment,
  });

  final IncidentStatus status;
  final DateTime? changedAt;
  final String? changedByName;
  final String? comment;
}

/// A recommendation the technician left on a case.
@immutable
class CaseRecommendation {
  const CaseRecommendation({
    required this.id,
    required this.description,
    required this.isConfirmed,
    this.dueDate,
    this.createdAt,
    this.isPending = false,
  });

  final String id;
  final String description;

  /// True once a confirmation (farmer or technician) exists.
  final bool isConfirmed;
  final DateTime? dueDate;
  final DateTime? createdAt;

  /// True while the recommendation or its confirmation is not on the server.
  final bool isPending;
}

/// A visit the technician scheduled for a case.
@immutable
class CaseVisit {
  const CaseVisit({required this.date, this.comment});

  final DateTime date;
  final String? comment;
}

@immutable
class IncidentDetail {
  const IncidentDetail({
    required this.summary,
    required this.description,
    required this.history,
    required this.photos,
    this.recommendations = const [],
    this.visit,
  });

  final IncidentSummary summary;
  final String? description;

  /// Oldest first.
  final List<IncidentHistoryEntry> history;
  final List<IncidentPhotoInfo> photos;
  final List<CaseRecommendation> recommendations;

  /// Next scheduled visit, when there is one.
  final CaseVisit? visit;
}
