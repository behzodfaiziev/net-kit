part of '../net_kit_manager.dart';

/// Error handling interceptor for the network manager
class ErrorHandlingInterceptor {
  /// The constructor for the ErrorHandlingInterceptor class
  ErrorHandlingInterceptor({
    required this.refreshTokenPath,
    required this.logger,
    required this.retryRequest,
    required this.onRefreshFailed,
    required this.requestQueue,
    required this.tokenManager,
    required this.errorParams,
    required this.accessTokenHeaderKey,
  });

  /// The path for the refresh token request
  final String? refreshTokenPath;

  /// The logger for the network manager
  final INetKitLogger logger;

  /// The function to retry a request
  final Future<Response<dynamic>> Function(RequestOptions requestOptions)
      retryRequest;

  /// The function to call when the refresh token request fails
  final OnRefreshFailed? onRefreshFailed;

  /// The request queue for the network manager
  final RequestQueue requestQueue;

  /// The token manager for the network manager
  final TokenManager tokenManager;

  /// Error message params for typed rejections.
  final NetKitErrorParams errorParams;

  /// Header key used to detect stale Authorization on retry.
  final String accessTokenHeaderKey;

  /// Completer for single-flight token refresh.
  Completer<void>? _refreshCompleter;

  /// Stores refresh failure for requests awaiting [ _refreshCompleter ].
  Object? _refreshFailure;

  /// Ensures [onRefreshFailed] is invoked once per refresh failure.
  bool _refreshFailedNotified = false;

  /// The maximum number of retries for a request
  static const int _maxRetryCount = 1;

  /// Returns the error interceptor
  Interceptor getErrorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode != HttpStatuses.unauthorized.code) {
          return handler.next(error);
        }

        if (error.requestOptions.extra[RequestExtraKeys.skipTokenRefresh] ==
            true) {
          return handler.next(error);
        }

        if (error.requestOptions.extra[RequestExtraKeys.isRefreshRequest] ==
            true) {
          return handler.reject(error);
        }

        if (_isRefreshTokenPath(error.requestOptions.path)) {
          requestQueue.rejectQueuedRequests();
          return handler.reject(error);
        }

        final retryCount =
            error.requestOptions.extra[RequestExtraKeys.retryCount] as int? ??
                0;
        if (retryCount >= _maxRetryCount) {
          return handler.reject(error);
        }

        final existingRefresh = _refreshCompleter;
        if (existingRefresh != null) {
          return _awaitRefreshAndRetry(error, handler, existingRefresh);
        }

        _refreshFailure = null;
        _refreshFailedNotified = false;
        _refreshCompleter = Completer<void>();
        try {
          logger.debug('Unauthorized request, refreshing token...');
          await tokenManager.refreshTokens();
          _refreshCompleter!.complete();
          await requestQueue.processQueue();
          return _finishAfterRefresh(error, handler);
        } catch (e) {
          _refreshFailure = e;
          if (!_refreshCompleter!.isCompleted) {
            _refreshCompleter!.complete();
          }
          requestQueue.rejectQueuedRequests();
          return _rejectRefreshFailure(error, handler, e);
        } finally {
          _refreshCompleter = null;
        }
      },
    );
  }

  Future<void> _awaitRefreshAndRetry(
    DioException error,
    ErrorInterceptorHandler handler,
    Completer<void> refreshCompleter,
  ) async {
    await refreshCompleter.future;
    final failure = _refreshFailure;
    if (failure != null) {
      return _rejectRefreshFailure(error, handler, failure);
    }
    return _finishAfterRefresh(error, handler);
  }

  Future<void> _rejectRefreshFailure(
    DioException error,
    ErrorInterceptorHandler handler,
    Object failure,
  ) async {
    final rejection = failure is DioException
        ? failure
        : DioException(
            requestOptions: error.requestOptions,
            error: failure,
            type: DioExceptionType.unknown,
          );
    if (!_refreshFailedNotified) {
      _refreshFailedNotified = true;
      onRefreshFailed?.call(
        statusCode: rejection.response?.statusCode ??
            (failure is ApiException
                ? failure.statusCode
                : error.response?.statusCode),
        exception: rejection,
      );
    }
    logger.error('Token refresh failed: $failure');
    return handler.reject(rejection);
  }

  Future<void> _finishAfterRefresh(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_canRetryOn401(error.requestOptions)) {
      return handler.reject(
        DioException(
          requestOptions: error.requestOptions,
          response: Response<dynamic>(
            requestOptions: error.requestOptions,
            statusCode: HttpStatuses.unauthorized.code,
            data: {
              errorParams.messageKey:
                  errorParams.nonIdempotentRetryBlockedError,
              errorParams.statusCodeKey: HttpStatuses.unauthorized.code,
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );
    }

    return _handleRetryRequest(error, handler);
  }

  bool _canRetryOn401(RequestOptions options) {
    if (options.extra[RequestExtraKeys.allowRetryOn401] == true) {
      return true;
    }

    final method = options.method.toUpperCase();
    return method == RequestMethod.get.name.toUpperCase() ||
        method == RequestMethod.put.name.toUpperCase() ||
        method == RequestMethod.delete.name.toUpperCase();
  }

  bool _isRefreshTokenPath(String path) {
    if (refreshTokenPath == null) {
      return false;
    }

    return _normalizePath(path) == _normalizePath(refreshTokenPath!);
  }

  String _normalizePath(String path) {
    final withoutQuery = path.split('?').first;
    return withoutQuery.replaceAll(RegExp(r'^/+|/+$'), '');
  }

  /// Handles the retry request
  Future<void> _handleRetryRequest(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final retryCount =
          error.requestOptions.extra[RequestExtraKeys.retryCount] as int? ?? 0;
      error.requestOptions.extra[RequestExtraKeys.retryCount] = retryCount + 1;

      final response = await retryRequest(error.requestOptions);
      return handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        return handler.reject(e);
      }
      return handler.reject(
        DioException(
          requestOptions: error.requestOptions,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }
}
