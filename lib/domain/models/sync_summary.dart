import 'package:flutter/foundation.dart';

/// Counts of outbox records that have not reached the server yet.
@immutable
class SyncSummary {
  const SyncSummary({this.pending = 0, this.error = 0});

  /// Records waiting for an upload, including those in flight.
  final int pending;

  /// Records whose last upload failed and will be retried.
  final int error;

  int get unsent => pending + error;

  bool get isAllSynced => unsent == 0;

  @override
  bool operator ==(Object other) =>
      other is SyncSummary && other.pending == pending && other.error == error;

  @override
  int get hashCode => Object.hash(pending, error);

  @override
  String toString() => 'SyncSummary(pending: $pending, error: $error)';
}

/// Live state of the sync engine, for status indicators.
@immutable
class SyncSnapshot {
  const SyncSnapshot({
    this.isSyncing = false,
    this.isOnline = true,
    this.lastSyncedAt,
    this.pendingCount = 0,
    this.failedCount = 0,
  });

  final bool isSyncing;
  final bool isOnline;
  final DateTime? lastSyncedAt;
  final int pendingCount;
  final int failedCount;

  SyncSnapshot copyWith({
    bool? isSyncing,
    bool? isOnline,
    DateTime? lastSyncedAt,
    int? pendingCount,
    int? failedCount,
  }) {
    return SyncSnapshot(
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SyncSnapshot &&
      other.isSyncing == isSyncing &&
      other.isOnline == isOnline &&
      other.lastSyncedAt == lastSyncedAt &&
      other.pendingCount == pendingCount &&
      other.failedCount == failedCount;

  @override
  int get hashCode =>
      Object.hash(isSyncing, isOnline, lastSyncedAt, pendingCount, failedCount);
}
