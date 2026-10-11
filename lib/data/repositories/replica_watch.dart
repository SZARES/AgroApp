import 'dart:async';

import 'local_store.dart';

/// Re-runs [compute] whenever any of [tables] changes in the replica.
///
/// Recomputations never overlap: changes that arrive while one is running
/// trigger exactly one more run afterwards. Errors reach the stream's
/// listener; the stream keeps running.
Stream<T> watchDerived<T>(
  LocalStore store,
  List<String> tables,
  Future<T> Function() compute,
) {
  late final StreamController<T> controller;
  final subscriptions = <StreamSubscription<Object?>>[];
  var running = false;
  var dirty = false;

  Future<void> run() async {
    if (running) {
      dirty = true;
      return;
    }
    running = true;
    try {
      do {
        dirty = false;
        try {
          final value = await compute();
          if (!controller.isClosed) controller.add(value);
        } on Object catch (error, stack) {
          if (!controller.isClosed) controller.addError(error, stack);
        }
      } while (dirty && !controller.isClosed);
    } finally {
      running = false;
    }
  }

  controller = StreamController<T>(
    onListen: () {
      for (final table in tables) {
        subscriptions.add(store.watchTable(table).listen((_) => run()));
      }
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      subscriptions.clear();
    },
  );
  return controller.stream;
}
