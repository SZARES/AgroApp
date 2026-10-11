import 'package:flutter/foundation.dart';

import 'incident.dart';
import 'incident_status.dart';
import 'parcel.dart';

/// Urgency of a case (`priority_level` enum on the backend).
enum CasePriority {
  low('low'),
  medium('medium'),
  high('high');

  const CasePriority(this.wire);

  final String wire;

  static CasePriority parse(Object? value) {
    for (final priority in values) {
      if (priority.wire == value) return priority;
    }
    return medium;
  }
}

/// One alert of the technician's inbox.
@immutable
class TechnicianCase {
  const TechnicianCase({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    required this.parcelId,
    required this.parcelName,
    required this.symptom,
    required this.priority,
    required this.status,
    required this.reportedAt,
    required this.isPending,
    this.cropName,
    this.photoCount = 0,
  });

  final String id;
  final String farmerId;
  final String farmerName;
  final String parcelId;
  final String parcelName;
  final String? cropName;
  final String symptom;
  final CasePriority priority;
  final IncidentStatus status;
  final DateTime? reportedAt;

  /// True while a change of this case has not reached the server.
  final bool isPending;
  final int photoCount;

  bool get isOpen => status.isOpen;
}

/// A case with everything the technician needs to work on it.
@immutable
class TechnicianCaseDetail {
  const TechnicianCaseDetail({
    required this.summary,
    required this.description,
    required this.history,
    required this.photos,
    required this.recommendations,
    this.farmerPhone,
    this.visit,
  });

  final TechnicianCase summary;
  final String? description;
  final String? farmerPhone;

  /// Oldest first.
  final List<IncidentHistoryEntry> history;
  final List<IncidentPhotoInfo> photos;
  final List<CaseRecommendation> recommendations;
  final CaseVisit? visit;
}

@immutable
class AssistanceSubtypeOption {
  const AssistanceSubtypeOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// Assistance type from the synced catalog, with its subtypes.
@immutable
class AssistanceCategoryOption {
  const AssistanceCategoryOption({
    required this.id,
    required this.name,
    this.subtypes = const [],
  });

  final String id;
  final String name;
  final List<AssistanceSubtypeOption> subtypes;
}

/// What the technician entered when registering an assistance.
@immutable
class AssistanceDraft {
  const AssistanceDraft({
    required this.categoryId,
    required this.observation,
    this.subtypeId,
    this.recommendation = '',
    this.nextReview,
    this.parcelId,
  });

  final String categoryId;
  final String? subtypeId;
  final String observation;

  /// Optional recommendation left for the farmer.
  final String recommendation;
  final DateTime? nextReview;

  /// Parcel the assistance was given on (assistance outside a case).
  final String? parcelId;
}

/// Parcels of the technician and the case a pin opens, per parcel.
@immutable
class TechnicianMapData {
  const TechnicianMapData({
    this.parcels = const [],
    this.caseByParcel = const {},
  });

  final List<Parcel> parcels;

  /// Most urgent open case of each parcel that has one.
  final Map<String, String> caseByParcel;
}

enum TechnicianFailure {
  notFound,
  farmerNotFound,
  invalidTransition,
  noCategory,
  emptyText,
}

class TechnicianException implements Exception {
  const TechnicianException(this.failure);

  final TechnicianFailure failure;

  @override
  String toString() => 'TechnicianException($failure)';
}
