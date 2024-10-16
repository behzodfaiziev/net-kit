part of '../net_kit_manager.dart';

class ErrorHandlingInterceptor {
  ErrorHandlingInterceptor({
    required this.netKitManager,
    required this.refreshTokenPath,
  }) {
    _addInterceptor();
  }
  
  final NetKitManager netKitManager;
  final String refreshTokenPath;
  final RequestQueue _requestQueue = RequestQueue();
  bool _isRefreshing = false;

  void _addInterceptor() {
    netKitManager.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (error.response?.statusCode == 401) {
            if (_isRefreshing) {
              // Queue the request while refreshing the token
              _requestQueue.add(() => _retryRequest(error, handler));
            } else {
              _isRefreshing = true;
              await _refreshToken(error, handler);
              _isRefreshing = false;
              await _requestQueue.processQueue();
            }
          } else {
            return handler.next(error);
          }
        },
      ),
    );
  }

  Future<void> _refreshToken(
      DioException error, ErrorInterceptorHandler handler) async {
    try {
      final refreshResponse = await netKitManager.request<dynamic>(
        refreshTokenPath,
        options: Options(
          method: RequestMethod.post.name.toUpperCase(),
        ),
        data: {
          netKitManager.parameters.refreshTokenKey:
              netKitManager._getRefreshToken(),
        },
      );

      final authToken = netKitManager.extractTokens(
        response: refreshResponse,
        accessTokenKey: netKitManager.parameters.accessTokenKey,
        refreshTokenKey: netKitManager.parameters.refreshTokenKey,
      );

      netKitManager
        ..addBearerToken(authToken.accessToken)
        ..addRefreshToken(authToken.refreshToken)

        // Notify about token updates (optional)
        ..onTokensUpdated(authToken);

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
      DioException error, ErrorInterceptorHandler handler) async {
    final response = await netKitManager.request<dynamic>(
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
