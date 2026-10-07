/// Classification of an `ApiException`.
///
/// Lets callers distinguish an HTTP error answered by the server from
/// failures that happened before or around the HTTP exchange, without
/// depending on any transport library's exception types.
enum ApiFailureType {
  /// The server answered with a non-2xx status. [response] exceptions carry
  /// the parsed error body in `message` / `messages` and the HTTP status in
  /// `statusCode`.
  response,

  /// The request never produced an HTTP response: DNS, TLS, socket, or an
  /// unusable transport response. Also used when the device is offline.
  transport,

  /// A connect, send, or receive timeout.
  timeout,

  /// The request was cancelled through its cancellation token.
  cancelled,

  /// Authentication could not be satisfied locally: the access token was
  /// required but missing, or a `401` could not be retried after a
  /// successful refresh (non-idempotent request). The session is intact.
  auth,

  /// The **refresh endpoint itself** answered HTTP `401`: the refresh
  /// credential was rejected and the session is over.
  ///
  /// This is the only failure type that means "sign the user out". net_kit
  /// raises it for exactly one condition, after which it has already cleared
  /// the stored tokens and called `onSessionInvalidated` once. A `401` from
  /// an ordinary API request, an offline device, a timeout, a `5xx` or `429`
  /// from the refresh endpoint, or a malformed refresh response never
  /// produces this type.
  sessionInvalidated,

  /// The response was received but could not be decoded into the requested
  /// model (empty body, non-map body, model parsing failure).
  decoding,

  /// The request was rejected before sending because of its configuration,
  /// for example a cross-origin URL while cross-origin requests are blocked,
  /// a non-replayable body on a redirect, or too many redirects.
  invalidRequest,

  /// Any other exception raised while performing the request, for example a
  /// file system error while opening an upload.
  unknown,
}
