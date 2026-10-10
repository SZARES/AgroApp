import 'package:flutter/material.dart';

import '../../../domain/models/sync_summary.dart';

/// Tells the farmer whether records are still waiting to be sent.
///
/// Failed uploads are worded like pending ones: the data is safe on the
/// device and will be retried, so there is nothing for the user to fix.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({
    super.key,
    required this.summary,
    this.isSyncing = false,
    this.onSyncNow,
  });

  final SyncSummary summary;
  final bool isSyncing;
  final VoidCallback? onSyncNow;

  String get _message {
    if (summary.isAllSynced) return 'Todo guardado';
    if (isSyncing) return 'Enviando registros…';
    return summary.unsent == 1
        ? '1 registro por enviar'
        : '${summary.unsent} registros por enviar';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final allSynced = summary.isAllSynced;
    final canSyncNow = !allSynced && !isSyncing && onSyncNow != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: allSynced
            ? colors.primaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              allSynced
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_upload_outlined,
              size: 32,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_message, style: theme.textTheme.titleMedium),
                  if (!allSynced)
                    Text(
                      'Sus datos están guardados en el teléfono.',
                      style: theme.textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
            if (canSyncNow)
              TextButton(
                onPressed: onSyncNow,
                child: const Text('Enviar ahora'),
              ),
          ],
        ),
      ),
    );
  }
}
