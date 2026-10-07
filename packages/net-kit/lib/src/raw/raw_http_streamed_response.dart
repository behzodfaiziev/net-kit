import 'raw_http_response.dart';

/// Transport response whose body is delivered as a stream.
///
/// [statusCode] and [headers] are available as soon as the response head
/// arrives; [body] yields chunks as they are received and honours
/// back-pressure, so nothing beyond the HTTP client's socket buffers is held
/// in memory. The caller must either consume [body] to completion or cancel
/// its subscription (or the request's cancellation token) so the connection
/// is released.
final class RawHttpStreamedResponse with RawHttpResponseView {
  /// Creates a streamed transport response.
  const RawHttpStreamedResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    this.redirected = false,
  });

  @override
  final bool redirected;

  @override
  final int statusCode;

  @override
  final Map<String, List<String>> headers;

  /// Response body chunks. Single-subscription.
  ///
  /// Cancelling the request's `NetKitCancellationToken` ends the stream with
  /// a `RawHttpException` of type `cancellation`.
  final Stream<List<int>> body;
}
