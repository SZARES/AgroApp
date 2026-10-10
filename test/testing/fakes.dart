import 'dart:async';

import 'package:hackathon/data/services/connectivity_service.dart';
import 'package:hackathon/data/services/sync_service.dart';
import 'package:hackathon/domain/models/outbox_record.dart';

typedef SyncHandler =
    FutureOr<SyncBatchResult> Function(List<OutboxRecord> records);

class FakeSyncService implements SyncService {
  FakeSyncService([this.handler]);

  /// Defaults to accepting every record.
  SyncHandler? handler;

  final List<List<OutboxRecord>> batches = [];
  final List<String> deviceIds = [];

  @override
  Future<SyncBatchResult> syncBatch({
    required String deviceId,
    required List<OutboxRecord> records,
  }) async {
    deviceIds.add(deviceId);
    batches.add(records);
    final handler = this.handler;
    if (handler != null) return handler(records);
    return SyncBatchResult(
      syncedIds: [for (final record in records) record.id],
      failures: const [],
    );
  }
}

class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.online = true});

  bool online;

  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  void setOnline(bool value) {
    online = value;
    _controller.add(value);
  }

  Future<void> close() => _controller.close();
}
