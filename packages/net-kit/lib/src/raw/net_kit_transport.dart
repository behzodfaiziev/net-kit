import 'raw_http_request.dart';
import 'raw_http_response.dart';
import 'raw_http_streamed_response.dart';

/// HTTP transport contract owned by net_kit.
///
/// A transport sends an absolute URL with exactly the headers and body it is
/// given and returns the status, headers, and body it receives. It has no
/// notion of API origin, access tokens, token refresh, retries, or models;
/// `NetKitManager` adds those on top of a transport, and applications use a
/// transport directly (as a `RawHttpClient`) for external URLs such as
/// signed object-storage uploads.
///
/// Implementations must:
///
/// - return every HTTP status, including `3xx` (when `followRedirects` is
///   false), `401`, and `5xx`, as a response;
/// - throw `RawHttpException` only for transport failures;
/// - stream `StreamRawHttpBody`, `ReplayableRawHttpBody`, and
///   `FileRawHttpBody` without buffering them, setting `Content-Length`;
/// - honour the request's `NetKitCancellationToken` and release the binding
///   when the request completes.
abstract interface class NetKitTransport {
  /// Sends [request] and buffers the whole response body in memory.
  Future<RawHttpResponse> send(RawHttpRequest request);

  /// Sends [request] and returns the response head as soon as it arrives,
  /// with the body as a back-pressured stream.
  Future<RawHttpStreamedResponse> sendStreamed(RawHttpRequest request);

  /// Releases the underlying HTTP client. In-flight requests fail when
  /// [force] is true.
  void close({bool force = false});
}
