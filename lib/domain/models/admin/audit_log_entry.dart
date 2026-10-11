import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One changed field between the old and new version of an audited record.
@immutable
class AuditChange {
  const AuditChange(this.field, this.before, this.after);

  final String field;
  final String? before;
  final String? after;
}

/// A row of `audit_logs`.
@immutable
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.tableName,
    required this.recordId,
    required this.createdAt,
    this.actorId,
    this.oldData,
    this.newData,
  });

  final String id;
  final String? actorId;
  final String action;
  final String tableName;
  final String recordId;
  final DateTime createdAt;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;

  static AuditLogEntry? tryFromRow(Map<String, dynamic> row) {
    final createdAt = DateTime.tryParse('${row['created_at']}');
    if (createdAt == null) return null;
    Map<String, dynamic>? asMap(Object? value) =>
        value is Map ? Map<String, dynamic>.from(value) : null;
    return AuditLogEntry(
      id: '${row['id']}',
      actorId: row['actor_id'] as String?,
      action: '${row['action']}',
      tableName: '${row['table_name']}',
      recordId: '${row['record_id']}',
      createdAt: createdAt,
      oldData: asMap(row['old_data']),
      newData: asMap(row['new_data']),
    );
  }

  /// Fields whose value differs (all fields for an insert or delete).
  /// Housekeeping timestamps are skipped.
  List<AuditChange> get changes {
    const skipped = {'updated_at', 'created_at'};
    final keys = {
      ...?oldData?.keys,
      ...?newData?.keys,
    }.where((key) => !skipped.contains(key)).toList()..sort();
    return [
      for (final key in keys)
        if (_show(oldData?[key]) != _show(newData?[key]))
          AuditChange(key, _show(oldData?[key]), _show(newData?[key])),
    ];
  }

  static String? _show(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return jsonEncode(value);
  }
}

/// Spanish label of an audit action.
String auditActionLabel(String action) => switch (action.toUpperCase()) {
  'INSERT' => 'Creó',
  'UPDATE' => 'Modificó',
  'DELETE' => 'Eliminó',
  _ => action,
};
