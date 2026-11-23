import 'dart:async';

/// Keeps read–modify–write operations from overwriting each other.
class SerialWrites {
  Future<void> _previous = Future.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = _previous.then((_) => operation());
    _previous = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }
}
