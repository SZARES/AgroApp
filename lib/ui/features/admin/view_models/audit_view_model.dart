import 'dart:async';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/foundation.dart';

import '../../../../data/repositories/admin_repository.dart';
import '../../../../domain/models/admin/admin_failure.dart';
import '../../../../domain/models/admin/audit_log_entry.dart';
import '../../../../utils/result.dart';

/// Read-only audit trail with table and date filters.
class AdminAuditViewModel extends ChangeNotifier {
  AdminAuditViewModel({required AdminRepository repository})
    : _repository = repository {
    _subscription = _repository.watchUsers().listen((users) {
      _actorNames = {for (final user in users) user.id: user.fullName};
      notifyListeners();
    }, onError: (Object _) {});
    unawaited(load());
  }

  /// Tables worth filtering by, shown as `table_name` in the log.
  static const limit = 200;

  final AdminRepository _repository;
  StreamSubscription<Object?>? _subscription;
  Map<String, String> _actorNames = const {};

  List<AuditLogEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  String? _table;
  DateTimeRange? _range;
  String? _selectedId;

  bool get loading => _loading;
  String? get error => _error;
  List<AuditLogEntry> get entries => _entries;
  String? get tableFilter => _table;
  DateTimeRange? get range => _range;

  AuditLogEntry? get selected {
    for (final entry in _entries) {
      if (entry.id == _selectedId) return entry;
    }
    return null;
  }

  /// Tables that appear in the loaded entries (for the filter).
  List<String> get knownTables => _seenTables.toList()..sort();
  final Set<String> _seenTables = {};

  String actorName(String? actorId) {
    if (actorId == null) return 'Sistema';
    return _actorNames[actorId] ?? 'Usuario desconocido';
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    final range = _range;
    final result = await _repository.fetchAuditLogs(
      limit: limit,
      table: _table,
      from: range?.start,
      // The end day is inclusive.
      to: range?.end.add(const Duration(days: 1)),
    );
    _loading = false;
    switch (result) {
      case Ok(:final value):
        _entries = value;
        _seenTables.addAll([for (final entry in value) entry.tableName]);
      case Error(:final error):
        _error = error is AdminFailureException
            ? error.message
            : 'No se pudo cargar la auditoría.';
    }
    notifyListeners();
  }

  Future<void> setTable(String? table) {
    _table = table;
    return load();
  }

  Future<void> setRange(DateTimeRange? range) {
    _range = range;
    return load();
  }

  void select(String id) {
    _selectedId = id;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
