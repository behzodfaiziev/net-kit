/// Caller-owned cancellation handle for `NetKitManager` and raw requests.
///
/// Contract:
///
/// - One token may be shared by any number of in-flight requests. [cancel]
///   cancels every request currently bound to it.
/// - [cancel] is idempotent and sticky. Once cancelled a token stays
///   cancelled, so binding a new request to it cancels that request before
///   anything is sent.
/// - Requests release their binding when they complete, whether they
///   succeed, fail, or are cancelled. A finished request keeps no callback
///   and no transport handle alive through the token.
/// - Cancelling after every bound request has completed is harmless.
///
/// The contract does not expose any HTTP-client implementation type.
final class NetKitCancellationToken {
  /// Creates a cancellation token.
  NetKitCancellationToken();

  bool _isCancelled = false;
  final List<void Function()> _listeners = [];

  /// Whether [cancel] has been called.
  bool get isCancelled => _isCancelled;

  /// Cancels every request bound to this token.
  void cancel() {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    final listeners = List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}

/// Binds [token] to a transport-specific cancel callback.
///
/// Returns a function that releases the binding; transports must call it once
/// the request completes so no callback outlives its request. When [token]
/// is already cancelled, [onCancel] runs immediately and nothing is bound.
///
/// Used by transport adapters. Not part of the package public API.
void Function() bindNetKitCancellationToken(
  NetKitCancellationToken token,
  void Function() onCancel,
) {
  if (token._isCancelled) {
    onCancel();
    return () {};
  }
  token._listeners.add(onCancel);
  return () => token._listeners.remove(onCancel);
}

/// Number of requests currently bound to [token].
///
/// Diagnostic helper for tests. Not part of the package public API.
int netKitCancellationBindingCount(NetKitCancellationToken token) =>
    token._listeners.length;
