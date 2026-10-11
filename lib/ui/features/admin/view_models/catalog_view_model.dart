import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/repositories/local_store.dart';
import '../../../../domain/models/admin/admin_failure.dart';
import '../../../../domain/models/admin/catalog_def.dart';
import '../../../../domain/models/admin/catalog_row_parser.dart';
import '../../../../domain/models/admin/field_def.dart';
import '../../../../utils/result.dart';

/// Rows, editing and saving for one [CatalogDef]; the same class serves every
/// catalog.
class AdminCatalogViewModel extends ChangeNotifier {
  AdminCatalogViewModel({
    required AdminRepository repository,
    required this.def,
  }) : _repository = repository {
    _listen();
  }

  final AdminRepository _repository;
  final CatalogDef def;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  List<JsonMap> _rows = const [];
  final Map<String, List<JsonMap>> _references = {};
  List<JsonMap> _joinRows = const [];

  bool _loading = true;
  Object? _loadError;
  String? _selectedId;
  bool _creating = false;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;
  Map<String, String> _fieldErrors = const {};

  bool get loading => _loading;
  bool get hasLoadError => _loadError != null;
  List<JsonMap> get rows => _rows;
  bool get creating => _creating;
  bool get busy => _busy;
  String? get message => _message;
  bool get messageIsError => _messageIsError;
  Map<String, String> get fieldErrors => _fieldErrors;
  String? get selectedId => _selectedId;

  JsonMap? get selected {
    for (final row in _rows) {
      if (row[def.idColumn] == _selectedId) return row;
    }
    return null;
  }

  /// Rows of the table feeding a reference dropdown.
  List<JsonMap> referenceRows(String table) => _references[table] ?? const [];

  /// Units available to pick for the allowed-units editor.
  List<JsonMap> get unitRows => referenceRows('units');

  /// Unit ids currently allowed for [ownerId].
  Set<String> allowedUnitIds(String ownerId) {
    final join = def.allowedUnits;
    if (join == null) return const {};
    return {
      for (final row in _joinRows)
        if (row[join.ownerColumn] == ownerId) '${row[join.unitColumn]}',
    };
  }

  /// Display text of [column] for [row]: reference ids become names.
  String display(JsonMap row, String column) {
    final value = row[column];
    if (value == null) return '';
    final field = def.field(column);
    if (field?.kind == FieldKind.reference && field!.referenceTable != null) {
      for (final ref in referenceRows(field.referenceTable!)) {
        if (ref['id'] == value) {
          return '${ref[field.referenceLabelColumn]}';
        }
      }
      return '';
    }
    if (field?.kind == FieldKind.dropdown) {
      for (final option in field!.options) {
        if (option.value == value) return option.label;
      }
    }
    if (value is Map || value is List) return value.toString();
    return '$value';
  }

  String title(JsonMap row) {
    final text = display(row, def.titleColumn);
    return text.isEmpty ? '(sin nombre)' : text;
  }

  String subtitle(JsonMap row) => [
    for (final column in def.subtitleColumns)
      if (display(row, column).isNotEmpty) display(row, column),
  ].join(' · ');

  bool isActive(JsonMap row) => row['active'] != false;

  void _listen() {
    _loading = true;
    _loadError = null;
    void watch(String table, void Function(List<JsonMap>) assign) {
      _subscriptions.add(
        _repository.watchRows(table).listen((rows) {
          assign(rows);
          _loading = false;
          notifyListeners();
        }, onError: _onLoadError),
      );
    }

    watch(def.table, (rows) {
      _rows = [...rows]..sort(_compare);
    });
    final tables = {
      for (final field in def.fields)
        if (field.referenceTable != null) field.referenceTable!,
      if (def.allowedUnits != null) 'units',
    };
    for (final table in tables) {
      watch(table, (rows) => _references[table] = rows);
    }
    final join = def.allowedUnits;
    if (join != null) watch(join.table, (rows) => _joinRows = rows);
  }

  int _compare(JsonMap a, JsonMap b) {
    if (def.hasSortOrder) {
      final byOrder = ((a['sort_order'] as num?) ?? 0).compareTo(
        (b['sort_order'] as num?) ?? 0,
      );
      if (byOrder != 0) return byOrder;
    }
    return title(a).toLowerCase().compareTo(title(b).toLowerCase());
  }

  void _onLoadError(Object error) {
    _loadError = error;
    _loading = false;
    notifyListeners();
  }

  Future<void> retry() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _listen();
    notifyListeners();
  }

  void select(String id) {
    _selectedId = id;
    _creating = false;
    _fieldErrors = const {};
    _message = null;
    notifyListeners();
  }

  void startCreate() {
    _creating = true;
    _selectedId = null;
    _fieldErrors = const {};
    _message = null;
    notifyListeners();
  }

  void cancelEdit() {
    _creating = false;
    _selectedId = null;
    _fieldErrors = const {};
    notifyListeners();
  }

  /// Validates [raw] form values and saves the row. [allowedUnitIds] (when the
  /// catalog has an allowed-units join) replaces the owner's unit set.
  Future<bool> save(
    Map<String, Object?> raw, {
    Set<String>? allowedUnitIds,
  }) async {
    final parsed = CatalogRowParser.parse(def, raw);
    if (!parsed.isValid) {
      _fieldErrors = parsed.errors;
      _message = 'Revise los campos marcados';
      _messageIsError = true;
      notifyListeners();
      return false;
    }
    _fieldErrors = const {};
    _busy = true;
    _message = null;
    notifyListeners();

    final row = {...parsed.row};
    if (!_creating && _selectedId != null) row[def.idColumn] = _selectedId;
    if (def.usesKeyAsId && _creating) {
      final key = row[def.idColumn] as String?;
      if (key != null && _rows.any((r) => r[def.idColumn] == key)) {
        return _finish(
          const Result.error(AdminFailureException(AdminFailure.duplicate)),
          '',
        );
      }
    }
    final saved = await _repository.saveCatalogRow(def, row);
    if (saved is Ok<JsonMap>) {
      final ownerId = '${saved.value[def.idColumn]}';
      final join = def.allowedUnits;
      if (join != null && allowedUnitIds != null) {
        final unitsResult = await _repository.setAllowedUnits(
          join,
          ownerId,
          allowedUnitIds.toList(),
        );
        if (unitsResult is Error<void>) {
          _selectedId = ownerId;
          _creating = false;
          return _finish(unitsResult, '');
        }
      }
      _selectedId = ownerId;
      _creating = false;
    }
    return _finish(saved, 'Cambios guardados');
  }

  Future<bool> setActive(JsonMap row, bool active) async {
    _busy = true;
    notifyListeners();
    final result = await _repository.setActive(
      def,
      '${row[def.idColumn]}',
      active,
    );
    if (!def.hasActive && result is Ok<void>) _selectedId = null;
    return _finish(
      result,
      def.hasActive
          ? (active ? 'Activado' : 'Desactivado')
          : 'Quitado de la lista',
    );
  }

  bool _finish(Result<Object?> result, String okText) {
    _busy = false;
    final ok = result is Ok<Object?>;
    _message = switch (result) {
      Ok() => okText,
      Error(:final error) =>
        error is AdminFailureException
            ? error.message
            : 'No se pudo completar la acción. Intente de nuevo.',
    };
    _messageIsError = !ok;
    notifyListeners();
    return ok;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
