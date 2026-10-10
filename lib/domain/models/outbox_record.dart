import 'package:flutter/foundation.dart';

import 'sync_status.dart';

/// A locally saved record waiting to be uploaded through `sync_batch`.
@immutable
class OutboxRecord {
  const OutboxRecord({
    required this.id,
    required this.tableName,
    required this.payload,
    required this.status,
    required this.attempts,
    required this.clientCreatedAt,
    required this.updatedAt,
    this.lastError,
  });

  final String id;
  final String tableName;
  final Map<String, dynamic> payload;
  final SyncStatus status;
  final int attempts;
  final String? lastError;
  final DateTime clientCreatedAt;
  final DateTime updatedAt;

  OutboxRecord copyWith({
    String? id,
    String? tableName,
    Map<String, dynamic>? payload,
    SyncStatus? status,
    int? attempts,
    ValueGetter<String?>? lastError,
    DateTime? clientCreatedAt,
    DateTime? updatedAt,
  }) {
    return OutboxRecord(
      id: id ?? this.id,
      tableName: tableName ?? this.tableName,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError != null ? lastError() : this.lastError,
      clientCreatedAt: clientCreatedAt ?? this.clientCreatedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
