import '../core/net_kit_cancellation_token.dart';
import '../core/net_kit_progress_callback.dart';
import '../core/net_kit_timeout.dart';
import 'raw_http_body.dart';
import 'raw_http_method.dart';

/// Alias kept for raw-transport code written against 5.5.
typedef RawHttpProgressCallback = NetKitProgressCallback;

/// A single transport request.
///
/// The caller owns headers. The transport does not inject authorization,
/// JSON content type, or API-specific headers.
final class RawHttpRequest {
  /// Creates a transport request.
  ///
  /// [uri] must be absolute (`hasScheme` and a non-empty host).
  RawHttpRequest({
    required this.uri,
    required this.method,
    this.headers = const {},
    this.body,
    this.timeout,
    this.cancellationToken,
    this.onSendProgress,
    this.onReceiveProgress,
    this.followRedirects = false,
  }) {
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'Must be an absolute URI');
    }
  }

  /// Absolute request URI, including scheme, host, path, and query.
  final Uri uri;

  /// HTTP method.
  final RawHttpMethod method;

  /// Caller-owned request headers.
  final Map<String, String> headers;

  /// Optional request body.
  final RawHttpBody? body;

  /// Per-request timeouts. `null` phases use the transport default.
  final NetKitTimeout? timeout;

  /// Optional cancellation handle.
  final NetKitCancellationToken? cancellationToken;

  /// Upload progress. `total` is the declared content length when known.
  final NetKitProgressCallback? onSendProgress;

  /// Download progress. `total` is the response `Content-Length` when known.
  final NetKitProgressCallback? onReceiveProgress;

  /// Whether the transport follows `3xx` redirects itself.
  ///
  /// Defaults to `false` so protocol statuses such as `308` stay visible and
  /// no header is forwarded to another origin without the caller seeing it.
  /// When `true`, the underlying HTTP client follows redirects with its own
  /// rules, which may forward every header to the redirect target.
  final bool followRedirects;

  /// Returns a copy with the given fields replaced.
  RawHttpRequest copyWith({
    Uri? uri,
    RawHttpMethod? method,
    Map<String, String>? headers,
    RawHttpBody? body,
    bool clearBody = false,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onSendProgress,
    NetKitProgressCallback? onReceiveProgress,
    bool? followRedirects,
  }) {
    return RawHttpRequest(
      uri: uri ?? this.uri,
      method: method ?? this.method,
      headers: headers ?? this.headers,
      body: clearBody ? null : body ?? this.body,
      timeout: timeout ?? this.timeout,
      cancellationToken: cancellationToken ?? this.cancellationToken,
      onSendProgress: onSendProgress ?? this.onSendProgress,
      onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
      followRedirects: followRedirects ?? this.followRedirects,
    );
  }
}
