/// How an outbox record reaches the backend.
enum SyncOp {
  /// Idempotent insert through the `sync_batch` RPC.
  batch,

  /// PostgREST upsert keyed on the row id.
  upsert,

  /// PostgREST update of an existing row, payload holds only the changes.
  update;

  static SyncOp parse(String? value) => SyncOp.values.firstWhere(
    (op) => op.name == value,
    orElse: () => SyncOp.batch,
  );
}
