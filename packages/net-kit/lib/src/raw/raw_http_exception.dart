/// Transport-level failure kinds for [RawHttpException].
///
/// HTTP status codes are not failures; they are returned on the response.
enum RawHttpFailureType {
  /// Connect, send, receive, or response-transform timeout.
  timeout,

  /// DNS or socket connection failure.
  connection,

  /// TLS handshake or certificate validation failure.
  tls,

  /// The request was cancelled.
  cancellation,

  /// The transport produced a response that cannot be used, for example one
  /// without an HTTP status code.
  invalidResponse,

  /// Unclassified transport failure.
  unknown,
}

/// Thrown when the transport cannot complete a request.
///
/// This is not an API-layer exception. Protocol statuses such as 308, 401,
/// 404, 410, and 500 are returned as a response instead.
final class RawHttpException implements Exception {
  /// Creates a transport exception.
  const RawHttpException({
    required this.message,
    required this.type,
    this.cause,
    this.uri,
  });

  /// Human-readable failure description.
  final String message;

  /// Failure classification.
  final RawHttpFailureType type;

  /// Underlying error, if any.
  final Object? cause;

  /// Request URI, when known.
  final Uri? uri;

  @override
  String toString() => 'RawHttpException($type): $message';
}
