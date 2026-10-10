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
