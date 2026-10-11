import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/repositories/supervisor_repository.dart';

void main() {
  const units = [
    {'id': 'u1', 'name': 'kilogramo', 'abbreviation': 'kg'},
    {'id': 'u2', 'name': 'saco', 'abbreviation': 'saco'},
  ];

  const parcels = [
    {'id': 'p1', 'zone_id': 'z1'},
    {'id': 'p2', 'zone_id': 'z2'},
  ];

  const zoneKpis = [
    {
      'zone_id': 'z1',
      'zone_name': 'Morropón',
      'active_farmers': 10,
      'open_alerts': 4,
      'attended_cases': 6,
      'closed_cases': 8,
      'technical_assistance_count': 12,
      'avg_attention_hours': 24.0,
    },
    {
      'zone_id': 'z2',
      'zone_name': 'Sullana',
      'active_farmers': 5,
      'open_alerts': 2,
      'attended_cases': 3,
      'closed_cases': 4,
      'technical_assistance_count': 6,
      'avg_attention_hours': 12.0,
    },
  ];

  const zoneSummaries = [
    {'zone_id': 'z1', 'producers': 20},
    {'zone_id': 'z2', 'producers': 10},
  ];

  const recommendationCompletion = [
    {'zone_id': 'z1', 'technician_id': 't1', 'issued': 10, 'confirmed': 8},
    {'zone_id': 'z2', 'technician_id': 't2', 'issued': 5, 'confirmed': 1},
  ];

  const cropCycleBalance = [
    {
      'parcel_id': 'p1',
      'total_expenses': 100,
      'sales_income': 0,
      'production_by_unit': [
        {
          'unit_id': 'u1',
          'total_quantity': 50,
          'household_quantity': 20,
          'surplus_quantity': 10,
        },
      ],
    },
    {
      'parcel_id': 'p2',
      'total_expenses': 200,
      'sales_income': 0,
      'production_by_unit': [
        {
          'unit_id': 'u1',
          'total_quantity': 30,
          'household_quantity': 10,
          'surplus_quantity': 5,
        },
        {
          'unit_id': 'u2',
          'total_quantity': 7,
          'household_quantity': 0,
          'surplus_quantity': 0,
        },
      ],
    },
  ];

  const assistances = [
    {'technician_id': 't1', 'parcel_id': 'p1'},
    {'technician_id': 't1', 'parcel_id': 'p1'},
    {'technician_id': 't2', 'parcel_id': 'p2'},
  ];

  const incidents = [
    {'assigned_technician_id': 't1', 'status': 'closed', 'parcel_id': 'p1'},
    {'assigned_technician_id': 't1', 'status': 'reported', 'parcel_id': 'p1'},
    {'assigned_technician_id': 't2', 'status': 'closed', 'parcel_id': 'p2'},
  ];

  final data = SupervisorDashboardAggregator.aggregate(
    zoneKpis: zoneKpis,
    zoneSummaries: zoneSummaries,
    recommendationCompletion: recommendationCompletion,
    cropCycleBalance: cropCycleBalance,
    parcels: parcels,
    assistances: assistances,
    incidents: incidents,
    units: units,
  );

  test('aggregates the global KPIs', () {
    final g = data.global;
    expect(g.activeFarmers, 15);
    expect(g.registeredFarmers, 30);
    expect(g.adoptionRate, closeTo(0.5, 1e-9));

    expect(g.openAlerts, 6);
    expect(g.closedAlerts, 12);
    expect(g.totalAlerts, 18);
    expect(g.alertResolutionRate, closeTo(12 / 18, 1e-9));

    expect(g.issuedRecommendations, 15);
    expect(g.confirmedRecommendations, 9);
    expect(g.recommendationRate, closeTo(0.6, 1e-9));

    // (24*6 + 12*3) / 9 = 20
    expect(g.avgResponseHours, closeTo(20.0, 1e-9));
  });

  test('aggregates production per unit without converting units', () {
    final g = data.global;
    expect(g.productionByUnit, {'kilogramo': 80.0, 'saco': 7.0});
    expect(g.householdByUnit, {'kilogramo': 30.0});
    expect(g.surplusByUnit, {'kilogramo': 15.0});
    expect(g.expensesByCurrency, {'PEN': 300.0});
  });

  test('builds technician load per technician (masked, no names)', () {
    final g = data.global;
    expect(g.technicianLoad, hasLength(2));
    final t1 = g.technicianLoad.firstWhere((t) => t.id == 't1');
    expect(t1.assistanceCount, 2);
    expect(t1.closedCases, 1);
    expect(t1.pendingCases, 1);
    final t2 = g.technicianLoad.firstWhere((t) => t.id == 't2');
    expect(t2.assistanceCount, 1);
    expect(t2.closedCases, 1);
    expect(t2.pendingCases, 0);
  });

  test('aggregates per-zone metrics and exposes zone options', () {
    expect(data.zones.map((z) => z.name), ['Morropón', 'Sullana']);
    final z1 = data.byZone['z1']!;
    expect(z1.adoptionRate, closeTo(0.5, 1e-9));
    expect(z1.totalAlerts, 12);
    expect(z1.recommendationRate, closeTo(0.8, 1e-9));
    expect(z1.avgResponseHours, 24.0);
    expect(z1.expensesByCurrency, {'PEN': 100.0});
    expect(z1.productionByUnit, {'kilogramo': 50.0});

    final z2 = data.byZone['z2']!;
    expect(z2.productionByUnit, {'kilogramo': 30.0, 'saco': 7.0});
  });

  test('current() falls back to global for unknown zone', () {
    expect(data.current(null), same(data.global));
    expect(data.current('nope'), same(data.global));
    expect(data.current('z1'), same(data.byZone['z1']));
  });

  test('empty input yields an empty dashboard', () {
    final empty = SupervisorDashboardAggregator.aggregate(
      zoneKpis: const [],
      zoneSummaries: const [],
      recommendationCompletion: const [],
      cropCycleBalance: const [],
      parcels: const [],
      assistances: const [],
      incidents: const [],
      units: const [],
    );
    expect(empty.zones, isEmpty);
    expect(empty.global.isEmpty, isTrue);
    expect(empty.global.adoptionRate, isNull);
    expect(empty.global.alertResolutionRate, isNull);
    expect(empty.global.recommendationRate, isNull);
    expect(empty.global.avgResponseHours, isNull);
  });
}
