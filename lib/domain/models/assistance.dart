import 'package:flutter/foundation.dart';

import 'incident.dart';
import 'record_support.dart';

/// Who gave the assistance; [wire] is the backend enum value.
enum AssistanceProvider {
  aider('AIDER'),
  senasa('SENASA'),
  other('OTHER');

  const AssistanceProvider(this.wire);

  final String wire;

  static AssistanceProvider? tryParse(Object? value) {
    for (final provider in values) {
      if (provider.wire == value) return provider;
    }
    return null;
  }
}

enum AssistanceStatus {
  scheduled,
  completed,
  cancelled;

  static AssistanceStatus? tryParse(Object? value) =>
      AssistanceStatus.values.asNameMap()['$value'];
}

@immutable
class AssistanceSummary {
  const AssistanceSummary({
    required this.id,
    required this.provider,
    required this.status,
    required this.date,
    required this.topic,
    required this.isPending,
    this.technicianName,
    this.institutionName,
  });

  final String id;
  final AssistanceProvider provider;
  final AssistanceStatus status;
  final DateTime? date;
  final String topic;
  final String? technicianName;
  final String? institutionName;
  final bool isPending;
}

@immutable
class AssistanceRecommendation {
  const AssistanceRecommendation({
    required this.id,
    required this.description,
    required this.isConfirmed,
    required this.isPending,
    this.dueDate,
  });

  final String id;
  final String description;
  final DateTime? dueDate;
  final bool isConfirmed;
  final bool isPending;
}

@immutable
class AssistanceDocumentInfo {
  const AssistanceDocumentInfo({
    required this.id,
    required this.storagePath,
    this.localPath,
    this.comment,
  });

  final String id;
  final String storagePath;

  /// Device copy, present until the server row replaces it.
  final String? localPath;
  final String? comment;
}

@immutable
class AssistanceDetail {
  const AssistanceDetail({
    required this.summary,
    required this.parcelName,
    required this.recommendations,
    required this.documents,
    this.categoryName,
    this.observations,
    this.nextFollowup,
  });

  final AssistanceSummary summary;
  final String parcelName;
  final String? categoryName;
  final String? observations;
  final DateTime? nextFollowup;
  final List<AssistanceRecommendation> recommendations;
  final List<AssistanceDocumentInfo> documents;
}

/// Parcels and topic categories of the external visit flow.
@immutable
class ExternalVisitCatalog {
  const ExternalVisitCatalog({
    this.parcels = const [],
    this.categories = const [],
  });

  final List<IncidentParcel> parcels;
  final List<CatalogOption> categories;
}

@immutable
class ExternalVisitDraft {
  const ExternalVisitDraft({
    required this.parcelId,
    required this.provider,
    required this.date,
    required this.categoryId,
    this.institutionName,
    this.comment,
    this.photos = const [],
  });

  static const maxPhotos = 3;

  final String parcelId;

  /// SENASA or other; never AIDER (the backend rejects farmer-made AIDER rows).
  final AssistanceProvider provider;
  final String? institutionName;
  final DateTime date;
  final String categoryId;
  final String? comment;
  final List<PickedPhoto> photos;
}
