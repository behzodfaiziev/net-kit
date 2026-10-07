/// Transport timeouts owned by net_kit.
///
/// Each phase is optional; `null` means the transport default (no limit for
/// the built-in Dio adapter). A per-request [NetKitTimeout] is merged over the
/// manager-wide one with [merge].
final class NetKitTimeout {
  /// Creates a timeout configuration.
  const NetKitTimeout({this.connect, this.send, this.receive});

  /// Time allowed to establish the connection.
  final Duration? connect;

  /// Time allowed to send the request body.
  final Duration? send;

  /// Time allowed between two received chunks of the response.
  final Duration? receive;

  /// Returns a copy where every phase set on [other] replaces this one.
  NetKitTimeout merge(NetKitTimeout? other) {
    if (other == null) {
      return this;
    }
    return NetKitTimeout(
      connect: other.connect ?? connect,
      send: other.send ?? send,
      receive: other.receive ?? receive,
    );
  }

  @override
  String toString() =>
      'NetKitTimeout(connect: $connect, send: $send, receive: $receive)';
}
