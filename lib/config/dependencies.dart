import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/app_database.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/local_store.dart';
import '../data/repositories/outbox_repository.dart';
import '../data/services/admin_service.dart';
import '../data/services/auth_service.dart';
import '../data/services/supabase_admin_service.dart';
import '../data/services/connectivity_service.dart';
import '../data/services/supabase_auth_service.dart';
import '../data/services/supabase_sync_service.dart';
import '../data/services/sync_service.dart';
import '../data/sync/sync_engine.dart';
import '../ui/features/auth/view_models/auth_view_model.dart';

/// App-wide dependencies, in the order they depend on each other.
List<SingleChildWidget> buildProviders(SupabaseClient supabaseClient) {
  return [
    Provider<AppDatabase>(
      create: (_) => AppDatabase(),
      dispose: (_, database) => database.close(),
    ),
    Provider<AuthService>(create: (_) => SupabaseAuthService(supabaseClient)),
    Provider<SyncService>(create: (_) => SupabaseSyncService(supabaseClient)),
    Provider<ConnectivityService>(create: (_) => DeviceConnectivityService()),
    Provider<OutboxRepository>(
      create: (context) => OutboxRepository(context.read()),
    ),
    Provider<LocalStore>(
      create: (context) => LocalStore(context.read(), context.read()),
    ),
    Provider<SyncEngine>(
      lazy: false,
      create: (context) => SyncEngine(
        repository: context.read(),
        localStore: context.read(),
        syncService: context.read(),
        connectivity: context.read(),
      )..start(),
      dispose: (_, engine) => engine.dispose(),
    ),
    Provider<AdminService>(create: (_) => SupabaseAdminService(supabaseClient)),
    Provider<AdminRepository>(
      create: (context) => DefaultAdminRepository(
        service: context.read(),
        store: context.read(),
        connectivity: context.read(),
        requestSync: () async {
          await context.read<SyncEngine>().syncNow(forcePull: true);
        },
      ),
    ),
    Provider<AuthRepository>(
      create: (context) => DefaultAuthRepository(
        service: context.read(),
        cache: DriftSessionCache(context.read()),
        outbox: context.read(),
        syncEngine: context.read(),
      ),
    ),
    ChangeNotifierProvider<AuthViewModel>(
      lazy: false,
      create: (context) => AuthViewModel(
        authRepository: context.read(),
        requestSync: () => context.read<SyncEngine>().syncNow(forcePull: true),
      )..bootstrap(),
    ),
  ];
}
