import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/local/app_database.dart';
import 'package:hackathon/data/repositories/local_store.dart';
import 'package:hackathon/data/repositories/outbox_repository.dart';
import 'package:hackathon/data/sync/sync_engine.dart';
import 'package:hackathon/domain/models/home_summary.dart';
import 'package:hackathon/ui/features/home/view_models/home_view_model.dart';

import '../../../testing/fakes.dart';
import '../../../testing/home_fakes.dart';

void main() {
  late AppDatabase database;
  late FakeConnectivityService connectivity;
  late FakeHomeRepository homeRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    connectivity = FakeConnectivityService(online: false);
    homeRepository = FakeHomeRepository();
  });

  tearDown(() async {
    await connectivity.close();
    await database.close();
  });

  HomeViewModel build({String fullName = 'Rosa Pérez'}) {
    final outbox = OutboxRepository(database);
    final viewModel = HomeViewModel(
      outboxRepository: outbox,
      homeRepository: homeRepository,
      syncEngine: SyncEngine(
        repository: outbox,
        localStore: LocalStore(database, outbox),
        syncService: FakeSyncService(),
        connectivity: connectivity,
      ),
      fullName: fullName,
    );
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  test('takes the first name from the full name', () {
    expect(HomeViewModel.firstNameOf('Rosa María Pérez'), 'Rosa');
    expect(HomeViewModel.firstNameOf('  Rosa  '), 'Rosa');
    expect(HomeViewModel.firstNameOf(''), '');
  });

  test('starts loading, then exposes the repository summary', () async {
    homeRepository = FakeHomeRepository(
      const HomeSummary(parcelName: 'Campo', harvestCount: 1),
    );
    final viewModel = build();
    expect(viewModel.isLoading, isTrue);

    await pumpEventQueue();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.firstName, 'Rosa');
    expect(viewModel.home.parcelName, 'Campo');
  });

  test('follows later summaries and survives stream errors', () async {
    final viewModel = build();
    await pumpEventQueue();

    homeRepository.emitError();
    await pumpEventQueue();
    expect(viewModel.loadFailed, isTrue);

    homeRepository.emit(const HomeSummary(parcelName: 'Otro'));
    await pumpEventQueue();
    expect(viewModel.loadFailed, isFalse);
    expect(viewModel.home.parcelName, 'Otro');
  });
}
