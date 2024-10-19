part of '../net_kit_manager.dart';

/// An interceptor that handles error responses and token refresh logic.
///
/// The `ErrorHandlingInterceptor` class is responsible for intercepting error
/// responses, particularly 401 Unauthorized errors, and handling token refresh
/// logic. It uses a `RequestQueue` to queue requests while the token is being
/// refreshed.
class ErrorHandlingInterceptor {
  /// Creates an instance of `ErrorHandlingInterceptor`.
  ///
  /// The [netKitManager] parameter is the instance of `NetKitManager` used to
  /// make network requests. The [refreshTokenPath] parameter is the endpoint
  /// used to refresh the token.
  ErrorHandlingInterceptor({
    required NetKitManager netKitManager,
    required RequestQueue requestQueue,
    required String? refreshTokenPath,
  })  : _netKitManager = netKitManager,
        _requestQueue = requestQueue,
        _refreshTokenPath = refreshTokenPath {
    _addInterceptor();
  }

  /// Instance of `NetKitManager`. Used to make network requests.
  final NetKitManager _netKitManager;

  /// The endpoint used to refresh the token.
  /// By default, the value is null.
  /// If the value is null, the interceptor will not refresh the token.
  final String? _refreshTokenPath;

  /// Instance of `RequestQueue`. Used to queue
  /// requests while refreshing the token.
  final RequestQueue _requestQueue;

  /// Indicates whether the token is being refreshed.
  /// By default, the value is false.
  /// If the value is true, the interceptor will queue
  /// requests while refreshing the token.
  /// If the value is false, the interceptor will refresh
  /// the token and retry the original request.
  /// The value is set to true while refreshing the token
  /// and set to false after refreshing the token.
  bool _isRefreshing = false;

  /// Adds the interceptor to the `NetKitManager`.
  ///
  /// This method is called internally to add the interceptor to the
  /// `NetKitManager`. It should not be called directly.
  void _addInterceptor() {
    _netKitManager.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (error.response?.statusCode != 401 || _refreshTokenPath == null) {
            return handler.next(error);
          }
          if (_isRefreshing) {
            // Queue the request while refreshing the token
            _requestQueue.add(() => _retryRequest(error, handler));
            return;
          }

          _isRefreshing = true;
          await _refreshToken(
            error: error,
            handler: handler,
            refreshTokenPath: _refreshTokenPath!,
          );
          _isRefreshing = false;
          await _requestQueue.processQueue();
        },
      ),
    );
  }

  /// Refreshes the authentication token.
  ///
  /// This method is called internally when a 401 Unauthorized error is
  /// encountered. It makes a request to the [refreshTokenPath] to get a new
  /// token and retries the original request.
  ///
  /// The [error] parameter is the original error that triggered the token
  /// refresh. The [handler] parameter is used to handle the response.
  Future<void> _refreshToken({
    required String refreshTokenPath,
    required DioException error,
    required ErrorInterceptorHandler handler,
  }) async {
    try {
      final refreshResponse = await _netKitManager.request<dynamic>(
        refreshTokenPath,
        options: Options(
          method: RequestMethod.post.name.toUpperCase(),
        ),
        data: {
          _netKitManager.parameters.refreshTokenKey:
              _netKitManager._getRefreshToken(),
        },
      );

      final authToken = _netKitManager.extractTokens(
        response: refreshResponse,
        accessTokenKey: _netKitManager.parameters.accessTokenKey,
        refreshTokenKey: _netKitManager.parameters.refreshTokenKey,
      );

      _netKitManager
        ..addBearerToken(authToken.accessToken)
        ..addRefreshToken(authToken.refreshToken)

        // Notify about token updates (optional)
        .._onTokensUpdated(authToken);

      // Retry the original request
      await _retryRequest(error, handler);
    } catch (e) {
      return handler.reject(
        DioException(
          requestOptions: error.requestOptions,
          error: e,
        ),
      );
    }
  }

  Future<void> _retryRequest(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final response = await _netKitManager.request<dynamic>(
      error.requestOptions.path,
      options: Options(
        method: error.requestOptions.method,
        headers: error.requestOptions.headers,
      ),
      data: error.requestOptions.data,
      queryParameters: error.requestOptions.queryParameters,
    );
    return handler.resolve(response);
  }
}
