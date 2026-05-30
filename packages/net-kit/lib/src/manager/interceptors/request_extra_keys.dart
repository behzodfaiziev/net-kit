import 'package:dio/dio.dart';

/// Internal keys stored on [RequestOptions.extra] for auth refresh behavior.
abstract final class RequestExtraKeys {
  /// Tracks how many times a request has been retried after token refresh.
  static const retryCount = '__retryCount';

  /// When true, automatic token refresh is skipped on 401.
  static const skipTokenRefresh = '__skipTokenRefresh';

  /// When true, POST requests may be replayed once after token refresh.
  static const allowRetryOn401 = '__allowRetryOn401';

  /// Idempotency key for safe request replay.
  static const idempotencyKey = '__idempotencyKey';

  /// Marks the in-flight OAuth refresh request.
  static const isRefreshRequest = '__isRefreshRequest';

  /// Upload send progress callback stored for retry replay.
  static const onSendProgress = '__onSendProgress';

  /// Download receive progress callback stored for retry replay.
  static const onReceiveProgress = '__onReceiveProgress';
}

/// Content type for the OAuth refresh token request body.
enum RefreshTokenContentType {
  /// JSON body (default, backward compatible).
  json,

  /// `application/x-www-form-urlencoded` body (RFC 6749).
  formUrlEncoded,
}
