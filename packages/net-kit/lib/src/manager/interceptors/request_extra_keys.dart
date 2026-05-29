/// Internal keys stored on [RequestOptions.extra] for auth refresh behavior.
abstract final class RequestExtraKeys {
  static const retryCount = '__retryCount';
  static const skipTokenRefresh = '__skipTokenRefresh';
  static const allowRetryOn401 = '__allowRetryOn401';
  static const idempotencyKey = '__idempotencyKey';
  static const isRefreshRequest = '__isRefreshRequest';
  static const onSendProgress = '__onSendProgress';
  static const onReceiveProgress = '__onReceiveProgress';
}

/// Content type for the OAuth refresh token request body.
enum RefreshTokenContentType {
  /// JSON body (default, backward compatible).
  json,

  /// `application/x-www-form-urlencoded` body (RFC 6749).
  formUrlEncoded,
}
