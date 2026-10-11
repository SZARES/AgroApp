import 'package:flutter/foundation.dart';

import 'parcel.dart';
import 'technician_case.dart';

/// A farmer of the technician's zones, as a row of the farmers list.
@immutable
class TechnicianFarmer {
  const TechnicianFarmer({
    required this.id,
    required this.name,
    this.phone,
    this.communityName,
    this.parcelCount = 0,
    this.openCaseCount = 0,
    this.lastAssistanceDate,
  });

  final String id;
  final String name;
  final String? phone;
  final String? communityName;
  final int parcelCount;
  final int openCaseCount;

  /// Date of the latest assistance given to the farmer, when there is one.
  final DateTime? lastAssistanceDate;
}

/// One assistance in the history of a farmer.
@immutable
class FarmerAssistanceEntry {
  const FarmerAssistanceEntry({
    required this.id,
    required this.date,
    required this.topic,
    required this.status,
    required this.isPending,
    this.parcelName,
  });

  final String id;
  final DateTime? date;
  final String topic;

  /// `scheduled`, `completed`, ... as stored.
  final String status;
  final bool isPending;
  final String? parcelName;

  bool get isScheduled => status == 'scheduled';
}

/// How many recommendations were issued to a farmer and how many they applied.
@immutable
class RecommendationCounts {
  const RecommendationCounts({this.issued = 0, this.confirmed = 0});

  final int issued;
  final int confirmed;
}

/// The farmer's file: contact, parcels, cases and assistance history.
@immutable
class TechnicianFarmerDetail {
  const TechnicianFarmerDetail({
    required this.farmer,
    this.parcels = const [],
    this.cases = const [],
    this.assistances = const [],
    this.recommendations = const RecommendationCounts(),
  });

  final TechnicianFarmer farmer;
  final List<Parcel> parcels;

  /// Newest first.
  final List<TechnicianCase> cases;

  /// Newest first.
  final List<FarmerAssistanceEntry> assistances;
  final RecommendationCounts recommendations;
}

/// Numbers of the technician's home dashboard, computed from the replica.
@immutable
class TechnicianKpis {
  const TechnicianKpis({
    this.openAlerts = 0,
    this.urgentAlerts = 0,
    this.attendedCases = 0,
    this.closedCases = 0,
    this.scheduledVisits = 0,
    this.activeFarmers = 0,
    this.recommendationsIssued = 0,
    this.recommendationsConfirmed = 0,
    this.avgResponseDays,
  });

  final int openAlerts;
  final int urgentAlerts;
  final int attendedCases;
  final int closedCases;
  final int scheduledVisits;
  final int activeFarmers;
  final int recommendationsIssued;
  final int recommendationsConfirmed;

  /// Average days from report to the first technician reaction; null when no
  /// case has been taken yet.
  final double? avgResponseDays;
}
