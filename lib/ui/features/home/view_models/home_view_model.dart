import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/outbox_repository.dart';
import '../../../../data/sync/sync_engine.dart';
import '../../../../domain/models/sync_summary.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required OutboxRepository outboxRepository,
    required SyncEngine syncEngine,
  }) : _syncEngine = syncEngine {
    _subscription = outboxRepository.watchSummary().listen((summary) {
      _summary = summary;
      notifyListeners();
    });
  }

  final SyncEngine _syncEngine;
  late final StreamSubscription<SyncSummary> _subscription;
  bool _isDisposed = false;

  SyncSummary get summary => _summary;
  SyncSummary _summary = const SyncSummary();

  bool get isSyncing => _isSyncing;
  bool _isSyncing = false;

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    await _syncEngine.syncPending();

    if (_isDisposed) return;
    _isSyncing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
