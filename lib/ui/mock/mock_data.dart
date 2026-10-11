/// Static sample data for the mobile mock. Replace with repositories later.
library;

enum FieldStatus { good, review, pending }

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
