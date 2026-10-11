/// Static sample data for the mobile mock. Replace with repositories later.
library;

import 'package:flutter/material.dart';

import '../core/widgets/field_map.dart';

enum FieldStatus { good, review, pending }

enum CaseStatus { reported, underReview, visitScheduled, attended, closed }

class MockField {
  const MockField({
    required this.name,
    required this.crop,
    required this.hectares,
    required this.status,
  });

  final String name;
  final String crop;
  final double hectares;
  final FieldStatus status;
}

class MockActivity {
  const MockActivity({
    required this.title,
    required this.field,
    required this.date,
    required this.cost,
  });

  final String title;
  final String field;
  final String date;
  final double cost;
}

class MockCase {
  const MockCase({
    required this.id,
    required this.problem,
    required this.field,
    required this.reportedAt,
    required this.status,
  });

  final String id;
  final String problem;
  final String field;
  final String reportedAt;
  final CaseStatus status;
}

class MockRecommendation {
  const MockRecommendation({required this.text, this.applied = false});

  final String text;
  final bool applied;
}

class MockAssistance {
  const MockAssistance({
    required this.id,
    required this.topic,
    required this.provider,
    required this.date,
    required this.recommendations,
  });

  final String id;
  final String topic;
  final String provider;
  final String date;
  final List<MockRecommendation> recommendations;
}

class MockTechnicianCase {
  const MockTechnicianCase({
    required this.id,
    required this.farmer,
    required this.field,
    required this.problem,
    required this.status,
    required this.urgent,
  });

  final String id;
  final String farmer;
  final String field;
  final String problem;
  final CaseStatus status;
  final bool urgent;
}

const mockFarmerName = 'Rosa';

const mockFields = [
  MockField(
    name: 'Campo del pozo',
    crop: 'Café',
    hectares: 1.2,
    status: FieldStatus.good,
  ),
  MockField(
    name: 'Campo de la quebrada',
    crop: 'Maíz',
    hectares: 0.8,
    status: FieldStatus.review,
  ),
  MockField(
    name: 'Campo del cerro',
    crop: 'Limón',
    hectares: 0.5,
    status: FieldStatus.pending,
  ),
];

double get mockTotalHectares =>
    mockFields.fold(0, (total, field) => total + field.hectares);

/// Field outlines for the map section, in normalized map space (0..1).
const mockMapFields = [
  MapFieldShape(
    name: 'Campo del pozo',
    points: [
      Offset(0.30, 0.24),
      Offset(0.42, 0.21),
      Offset(0.44, 0.40),
      Offset(0.33, 0.42),
    ],
  ),
  MapFieldShape(
    name: 'Campo de la quebrada',
    points: [
      Offset(0.05, 0.44),
      Offset(0.22, 0.46),
      Offset(0.28, 0.66),
      Offset(0.10, 0.70),
    ],
  ),
  MapFieldShape(
    name: 'Campo del cerro',
    points: [
      Offset(0.30, 0.66),
      Offset(0.56, 0.78),
      Offset(0.46, 0.92),
      Offset(0.26, 0.80),
    ],
  ),
];

/// Incident pins for the map section, in normalized map space (0..1).
const mockMapPins = [
  MapPin(position: Offset(0.37, 0.27)),
  MapPin(position: Offset(0.14, 0.56), resolved: true),
  MapPin(position: Offset(0.40, 0.76)),
];

const mockActivities = [
  MockActivity(
    title: 'Riego',
    field: 'Campo del pozo',
    date: '08/10/2026',
    cost: 15,
  ),
  MockActivity(
    title: 'Abono',
    field: 'Campo de la quebrada',
    date: '06/10/2026',
    cost: 80,
  ),
  MockActivity(
    title: 'Poda',
    field: 'Campo del cerro',
    date: '02/10/2026',
    cost: 0,
  ),
];

const mockCases = [
  MockCase(
    id: 'C-014',
    problem: 'Plaga en las hojas',
    field: 'Campo de la quebrada',
    reportedAt: '07/10/2026',
    status: CaseStatus.visitScheduled,
  ),
  MockCase(
    id: 'C-009',
    problem: 'Falta de agua',
    field: 'Campo del pozo',
    reportedAt: '01/10/2026',
    status: CaseStatus.closed,
  ),
];

const mockAssistances = [
  MockAssistance(
    id: 'A-031',
    topic: 'Manejo de plagas en maíz',
    provider: 'AIDER',
    date: '03/10/2026',
    recommendations: [
      MockRecommendation(
        text: 'Revisar el envés de las hojas cada semana.',
        applied: true,
      ),
      MockRecommendation(text: 'Aplicar caldo de ajo cada 7 días.'),
      MockRecommendation(text: 'Retirar las hojas muy dañadas.'),
    ],
  ),
  MockAssistance(
    id: 'A-022',
    topic: 'Poda de café',
    provider: 'SENASA',
    date: '15/09/2026',
    recommendations: [
      MockRecommendation(text: 'Podar ramas secas antes de la floración.'),
    ],
  ),
];

const mockTechnicianCases = [
  MockTechnicianCase(
    id: 'C-014',
    farmer: 'Rosa Quispe',
    field: 'Campo de la quebrada',
    problem: 'Plaga en las hojas',
    status: CaseStatus.reported,
    urgent: true,
  ),
  MockTechnicianCase(
    id: 'C-015',
    farmer: 'Julio Chávez',
    field: 'Campo del cerro',
    problem: 'Hojas amarillas',
    status: CaseStatus.underReview,
    urgent: false,
  ),
  MockTechnicianCase(
    id: 'C-011',
    farmer: 'Marta Vásquez',
    field: 'Campo del pozo',
    problem: 'Falta de agua',
    status: CaseStatus.visitScheduled,
    urgent: false,
  ),
];

/// Labels in the incident lifecycle order (`reported` → `closed`).
const caseStatusLabels = {
  CaseStatus.reported: 'Reportado',
  CaseStatus.underReview: 'En revisión',
  CaseStatus.visitScheduled: 'Visita programada',
  CaseStatus.attended: 'Atendido',
  CaseStatus.closed: 'Cerrado',
};
