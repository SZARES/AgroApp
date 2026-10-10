import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/app_database.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/outbox_repository.dart';
import '../data/services/connectivity_service.dart';
import '../data/services/supabase_sync_service.dart';
import '../data/services/sync_service.dart';
import '../data/sync/sync_engine.dart';

/// App-wide dependencies, in the order they depend on each other.
List<SingleChildWidget> buildProviders(SupabaseClient supabaseClient) {
  return [
    Provider<AppDatabase>(
      create: (_) => AppDatabase(),
      dispose: (_, database) => database.close(),
    ),
    Provider<AuthRepository>(create: (_) => const MockAuthRepository()),
    Provider<SyncService>(create: (_) => SupabaseSyncService(supabaseClient)),
    Provider<ConnectivityService>(create: (_) => DeviceConnectivityService()),
    Provider<OutboxRepository>(
      create: (context) => OutboxRepository(context.read()),
    ),
    Provider<SyncEngine>(
      lazy: false,
      create: (context) => SyncEngine(
        repository: context.read(),
        syncService: context.read(),
        connectivity: context.read(),
      )..start(),
      dispose: (_, engine) => engine.dispose(),
    ),
  ];
}
