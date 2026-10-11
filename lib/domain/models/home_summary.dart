import 'package:flutter/foundation.dart';

import 'incident_status.dart';

/// What the farmer home shows, derived from the local replica.
@immutable
class HomeSummary {
  const HomeSummary({
    this.parcelName,
    this.parcelCount = 0,
    this.hasLocation = false,
    this.locationLabel,
    this.lastFertilization,
    this.nextRecommendation,
    this.activeIncident,
    this.activeIncidentId,
    this.harvestCount = 0,
    this.productionKg,
  });

  static const empty = HomeSummary();

  /// Name of the main parcel; null when the farmer has none yet.
  final String? parcelName;
  final int parcelCount;
  final bool hasLocation;

  /// Zone and community of the farmer, e.g. "Morropón · La Matanza".
  final String? locationLabel;
  final DateTime? lastFertilization;
  final String? nextRecommendation;

  /// Status of the most recent unresolved problem; null when there is none.
  final IncidentStatus? activeIncident;

  /// Id of that problem, to open its status screen.
  final String? activeIncidentId;
  final int harvestCount;

  /// Sum of the estimated weights of all harvests; null when none has one.
  final double? productionKg;

  @override
  bool operator ==(Object other) =>
      other is HomeSummary &&
      other.parcelName == parcelName &&
      other.parcelCount == parcelCount &&
      other.hasLocation == hasLocation &&
      other.locationLabel == locationLabel &&
      other.lastFertilization == lastFertilization &&
      other.nextRecommendation == nextRecommendation &&
      other.activeIncident == activeIncident &&
      other.activeIncidentId == activeIncidentId &&
      other.harvestCount == harvestCount &&
      other.productionKg == productionKg;

  @override
  int get hashCode => Object.hash(
    parcelName,
    parcelCount,
    hasLocation,
    locationLabel,
    lastFertilization,
    nextRecommendation,
    activeIncident,
    activeIncidentId,
    harvestCount,
    productionKg,
  );
}
