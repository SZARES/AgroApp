import 'dart:async';

import 'package:flutter/foundation.dart';

/// Holds the latest value of a repository stream for a list or detail screen.
class StreamViewModel<T> extends ChangeNotifier {
  StreamViewModel({required Stream<T> stream, required T initial})
    : _value = initial {
    _subscription = stream.listen(
      (value) {
        _value = value;
        _isLoading = false;
        _loadFailed = false;
        notifyListeners();
      },
      onError: (Object _) {
        _isLoading = false;
        _loadFailed = true;
        notifyListeners();
      },
    );
  }

  late final StreamSubscription<T> _subscription;
  T _value;
  bool _isLoading = true;
  bool _loadFailed = false;

  T get value => _value;
  bool get isLoading => _isLoading;
  bool get loadFailed => _loadFailed;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
