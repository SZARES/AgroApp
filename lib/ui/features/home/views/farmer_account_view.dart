import 'package:flutter/material.dart';

import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/sync_status_indicator.dart';
import '../view_models/home_view_model.dart';

/// "Mi cuenta": name, sync status and sign-out — replaces the floating logout.
class FarmerAccountView extends StatelessWidget {
  const FarmerAccountView({
    super.key,
    required this.viewModel,
    required this.onSignOut,
  });

  final HomeViewModel viewModel;
  final VoidCallback onSignOut;

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Podrá volver a entrar con su DNI y contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok == true) onSignOut();
  }

  Future<void> _sync(BuildContext context) async {
    showAppLoading(context, message: 'Enviando registros…');
    final message = await viewModel.syncNow();
    if (!context.mounted) return;
    hideAppLoading(context);
    if (message.isEmpty) return;
    showAppSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final name = viewModel.fullName.isEmpty
                ? 'Agricultor'
                : viewModel.fullName;
            final initial = viewModel.firstName.isEmpty
                ? '?'
                : viewModel.firstName.substring(0, 1).toUpperCase();

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 8),
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      initial,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  'Agricultor',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                Text('Sus datos', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                SyncStatusIndicator(
                  summary: viewModel.summary,
                  isSyncing: viewModel.isSyncing,
                  onSyncNow: () => _sync(context),
                ),
                const SizedBox(height: 28),
                Text('Opciones', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Icon(
                          Icons.cloud_upload_outlined,
                          size: 32,
                          color: scheme.primary,
                        ),
                        title: Text(
                          'Enviar datos ahora',
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          'Sube lo que quedó pendiente',
                          style: theme.textTheme.bodyMedium,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 32),
                        onTap: viewModel.isSyncing
                            ? null
                            : () => _sync(context),
                      ),
                      Divider(height: 1, color: scheme.outline),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Icon(
                          Icons.logout,
                          size: 32,
                          color: scheme.secondary,
                        ),
                        title: Text(
                          'Cerrar sesión',
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          'Salir de esta cuenta',
                          style: theme.textTheme.bodyMedium,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 32),
                        onTap: () => _confirmSignOut(context),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
