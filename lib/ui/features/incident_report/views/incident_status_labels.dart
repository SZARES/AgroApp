import 'package:flutter/material.dart';

import '../../../../domain/models/incident_status.dart';

/// Short farmer-facing name of a case status.
String incidentStatusName(IncidentStatus status) => switch (status) {
  IncidentStatus.reported => 'Reportado',
  IncidentStatus.underReview => 'En revisión',
  IncidentStatus.visitScheduled => 'Visita programada',
  IncidentStatus.attended => 'Atendido',
  IncidentStatus.closed => 'Cerrado',
};

IconData incidentStatusIcon(IncidentStatus status) => switch (status) {
  IncidentStatus.reported => Icons.notification_important_outlined,
  IncidentStatus.underReview => Icons.search,
  IncidentStatus.visitScheduled => Icons.event_available_outlined,
  IncidentStatus.attended => Icons.handshake_outlined,
  IncidentStatus.closed => Icons.task_alt,
};

const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// "5 may 2026, 14:05".
String formatIncidentDate(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${_months[date.month - 1]} ${date.year}, $hour:$minute';
}
