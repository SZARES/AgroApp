import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/domain/models/incident_status.dart';
import 'package:hackathon/domain/models/technician_case.dart';
import 'package:hackathon/domain/models/technician_farmer.dart';
import 'package:hackathon/ui/features/technician/view_models/technician_cases_view_model.dart';
import 'package:hackathon/ui/features/technician/view_models/technician_dashboard_view_model.dart';
import 'package:hackathon/ui/features/technician/view_models/technician_farmer_view_model.dart';
import 'package:hackathon/ui/features/technician/view_models/technician_farmers_view_model.dart';

import '../../../testing/technician_fakes.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeTechnicianRepository repository;

  setUp(() => repository = FakeTechnicianRepository());

  group('TechnicianCasesViewModel filters', () {
    late TechnicianCasesViewModel viewModel;

    setUp(() async {
      viewModel = TechnicianCasesViewModel(repository: repository);
      addTearDown(viewModel.dispose);
      repository.cases.add([
        fakeCase('urgent', priority: CasePriority.high),
        fakeCase('new'),
        fakeCase('visit', status: IncidentStatus.visitScheduled),
        fakeCase('attended', status: IncidentStatus.attended),
        fakeCase(
          'closed-urgent',
          priority: CasePriority.high,
          status: IncidentStatus.closed,
        ),
      ]);
      await settle();
    });

    List<String> ids(CaseFilter filter) {
      viewModel.setFilter(filter);
      return viewModel.filteredCases.map((c) => c.id).toList();
    }

    test('starts on "all" and loaded', () {
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.filter, CaseFilter.all);
      expect(viewModel.filteredCases, hasLength(5));
    });

    test('each filter keeps the matching cases in order', () {
      expect(ids(CaseFilter.urgent), ['urgent']);
      expect(ids(CaseFilter.open), ['urgent', 'new', 'visit', 'attended']);
      expect(ids(CaseFilter.scheduled), ['visit']);
      expect(ids(CaseFilter.closed), ['closed-urgent']);
      expect(ids(CaseFilter.all), hasLength(5));
    });

    test('openCount stays the total of open cases whatever the filter', () {
      viewModel.setFilter(CaseFilter.closed);

      expect(viewModel.openCount, 4);
      expect(viewModel.countFor(CaseFilter.urgent), 1);
    });

    test('labels are in Spanish', () {
      expect(CaseFilter.values.map((f) => f.label), [
        'Todos',
        'Urgentes',
        'Abiertos',
        'Visita programada',
        'Cerrados',
      ]);
    });

    test('notifies only when the filter changes', () {
      var notified = 0;
      viewModel.addListener(() => notified++);

      viewModel.setFilter(CaseFilter.urgent);
      viewModel.setFilter(CaseFilter.urgent);

      expect(notified, 1);
    });

    test('attention cases skip attended and closed ones', () {
      expect(viewModel.attentionCases().map((c) => c.id), [
        'urgent',
        'new',
        'visit',
      ]);
      expect(viewModel.attentionCases(limit: 1), hasLength(1));
    });
  });

  test('cases view model reports a load failure', () async {
    final viewModel = TechnicianCasesViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await settle(); // let the feed start listening
    repository.cases.addError(StateError('boom'));
    await settle();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.loadFailed, isTrue);
  });

  test('farmers view model loads, selects and fails gracefully', () async {
    final viewModel = TechnicianFarmersViewModel(repository: repository);
    addTearDown(viewModel.dispose);
    expect(viewModel.isLoading, isTrue);

    repository.farmers.add(const [TechnicianFarmer(id: 'f1', name: 'Rosa')]);
    await settle();
    viewModel.select('f1');

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.farmers.single.name, 'Rosa');
    expect(viewModel.selectedId, 'f1');

    await settle();
    repository.farmers.addError(StateError('boom'));
    await settle();
    expect(viewModel.loadFailed, isTrue);
  });

  test('dashboard view model exposes the KPIs', () async {
    final viewModel = TechnicianDashboardViewModel(repository: repository);
    addTearDown(viewModel.dispose);
    expect(viewModel.isLoading, isTrue);

    repository.kpis.add(const TechnicianKpis(openAlerts: 3, activeFarmers: 7));
    await settle();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.kpis.openAlerts, 3);
    expect(viewModel.kpis.activeFarmers, 7);
  });

  test('farmer view model registers assistance on the chosen parcel', () async {
    final viewModel = TechnicianFarmerViewModel(
      repository: repository,
      farmerId: 'f1',
    );
    addTearDown(viewModel.dispose);
    const draft = AssistanceDraft(
      categoryId: 'cat',
      observation: 'Visité el campo',
      parcelId: 'p-from-draft',
    );

    await viewModel.registerAssistance(draft);
    await viewModel.registerAssistance(draft, parcelId: 'p-explicit');

    expect(repository.fieldAssistances.map((c) => c.parcelId), [
      'p-from-draft',
      'p-explicit',
    ]);
    expect(repository.fieldAssistances.first.farmerId, 'f1');
    expect(viewModel.isBusy, isFalse);
  });

  test('farmer view model refuses a second save while busy', () async {
    final viewModel = TechnicianFarmerViewModel(
      repository: repository,
      farmerId: 'f1',
    );
    addTearDown(viewModel.dispose);
    const draft = AssistanceDraft(categoryId: 'c', observation: 'x');

    final first = viewModel.registerAssistance(draft);
    final second = await viewModel.registerAssistance(draft);
    await first;

    expect(second.toString(), contains('invalidTransition'));
    expect(repository.fieldAssistances, hasLength(1));
  });
}
