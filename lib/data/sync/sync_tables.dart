/// One backend table replicated into the local database.
class SyncTable {
  const SyncTable(
    this.name, {
    this.cursorColumn = 'updated_at',
    this.keyColumns = const ['id'],
    this.fullRefresh = false,
  });

  final String name;

  /// Column used for incremental pulls (ascending, `>` last seen value).
  final String cursorColumn;

  /// Primary-key columns; several are joined with `|` into the local id.
  final List<String> keyColumns;

  /// Tables without a cursor column are replaced wholesale on every pull.
  final bool fullRefresh;

  String rowId(Map<String, dynamic> row) =>
      keyColumns.map((column) => '${row[column]}').join('|');
}

/// Registry of replicated tables, parents before children.
abstract final class SyncTables {
  static const pullTables = <SyncTable>[
    // Catalogs.
    SyncTable('zones'),
    SyncTable('communities'),
    SyncTable('crops'),
    SyncTable('units'),
    SyncTable('unit_equivalences'),
    SyncTable('products'),
    SyncTable('activity_types'),
    SyncTable('pruning_types'),
    SyncTable('symptom_types'),
    SyncTable('assistance_categories'),
    SyncTable('assistance_subtypes'),
    SyncTable('expense_categories'),
    SyncTable('buyers'),
    SyncTable('reference_prices'),
    SyncTable('app_settings', keyColumns: ['key']),
    SyncTable(
      'activity_type_units',
      keyColumns: ['activity_type_id', 'unit_id'],
      fullRefresh: true,
    ),
    SyncTable(
      'product_units',
      keyColumns: ['product_id', 'unit_id'],
      fullRefresh: true,
    ),
    SyncTable(
      'crop_harvest_units',
      keyColumns: ['crop_id', 'unit_id'],
      fullRefresh: true,
    ),
    // Domain tables.
    SyncTable('profiles'),
    SyncTable(
      'user_zones',
      keyColumns: ['user_id', 'zone_id'],
      fullRefresh: true,
    ),
    SyncTable('farmers'),
    SyncTable('parcels'),
    SyncTable(
      'technician_parcels',
      keyColumns: ['technician_id', 'parcel_id'],
      fullRefresh: true,
    ),
    SyncTable('crop_cycles'),
    SyncTable('activities'),
    SyncTable('expenses'),
    SyncTable('incidents'),
    SyncTable('incident_photos'),
    SyncTable('incident_status_history', cursorColumn: 'changed_at'),
    SyncTable('technical_assistance'),
    SyncTable('assistance_documents'),
    SyncTable('recommendations'),
    SyncTable('recommendation_confirmations'),
    SyncTable('recommendation_followups'),
    SyncTable('visit_attendance_confirmations'),
    SyncTable('reminders'),
    SyncTable('harvests'),
    SyncTable('surplus_sales'),
    SyncTable('residue_management'),
    SyncTable('notifications'),
  ];

  /// Tables the server `sync_batch` RPC accepts (insert-only, idempotent).
  static const batchTables = <String>{
    'activities',
    'expenses',
    'incidents',
    'incident_photos',
    'harvests',
    'surplus_sales',
    'residue_management',
    'recommendation_confirmations',
    'technical_assistance',
    'assistance_documents',
    'visit_attendance_confirmations',
  };

  /// Tables intentionally not replicated: audit_logs, sync_log, device_tokens.
  static const notReplicated = <String>{
    'audit_logs',
    'sync_log',
    'device_tokens',
  };
}
