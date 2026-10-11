import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/home_repository.dart';
import '../../../../data/repositories/outbox_repository.dart';
import '../../../../data/sync/sync_engine.dart';
import '../../../../domain/models/home_summary.dart';
import '../../../../domain/models/sync_summary.dart';
import '../../../../utils/result.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required OutboxRepository outboxRepository,
    required HomeRepository homeRepository,
    required SyncEngine syncEngine,
    required String fullName,
  }) : _syncEngine = syncEngine,
       firstName = firstNameOf(fullName) {
    _outboxSubscription = outboxRepository.watchSummary().listen((summary) {
      _summary = summary;
      notifyListeners();
    });
    _homeSubscription = homeRepository.watchSummary().listen(
      (home) {
        _home = home;
        _isLoading = false;
        _loadFailed = false;
        notifyListeners();
      },
      onError: (Object _) {
        _isLoading = false;
        _loadFailed = true;
        notifyListeners();
      },
    );
  }

  final SyncEngine _syncEngine;
  late final StreamSubscription<SyncSummary> _outboxSubscription;
  late final StreamSubscription<HomeSummary> _homeSubscription;
  bool _isDisposed = false;

  /// First given name of the signed-in farmer; empty when unknown.
  final String firstName;

  SyncSummary get summary => _summary;
  SyncSummary _summary = const SyncSummary();

  HomeSummary get home => _home;
  HomeSummary _home = HomeSummary.empty;

  bool get isLoading => _isLoading;
  bool _isLoading = true;

  bool get loadFailed => _loadFailed;
  bool _loadFailed = false;

  bool get isSyncing => _isSyncing;
  bool _isSyncing = false;

  /// Pushes pending outbox rows. Returns a short user-facing message.
  Future<String> syncNow() async {
    if (_isSyncing) return 'Ya se está enviando';
    _isSyncing = true;
    notifyListeners();

    final result = await _syncEngine.syncNow(retryFailed: true);

    if (_isDisposed) return '';
    _isSyncing = false;
    notifyListeners();

    return switch (result) {
      Ok(:final value) when value.synced > 0 && value.failed > 0 =>
        'Se enviaron ${value.synced}. Quedan pendientes',
      Ok(:final value) when value.synced > 0 =>
        value.synced == 1
            ? '1 registro enviado'
            : '${value.synced} registros enviados',
      Ok(:final value) when value.failed > 0 && value.synced == 0 =>
        'No se pudo enviar. Intente de nuevo en un momento',
      Ok() when _summary.isAllSynced => 'Todo guardado',
      Ok() when !_syncEngine.snapshot.isOnline =>
        'Sin conexión. Se enviará cuando haya internet',
      Ok() => 'Aún hay registros por enviar',
      Error() => 'No se pudo enviar. Intente de nuevo en un momento',
    };
  }

  /// "Rosa Maria Perez" -> "Rosa"; blank input -> "".
  @visibleForTesting
  static String firstNameOf(String fullName) =>
      fullName.trim().split(RegExp(r'\s+')).first;

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_outboxSubscription.cancel());
    unawaited(_homeSubscription.cancel());
    super.dispose();
  }
}
