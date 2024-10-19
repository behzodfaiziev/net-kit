part of '../net_kit_manager.dart';

class ErrorHandlingInterceptor {

  ErrorHandlingInterceptor({
    required this.refreshTokenPath,
    required this.requestQueue,
    required this.tokenManager,
  });
  final String? refreshTokenPath;
  final RequestQueue requestQueue;
  bool _isRefreshing = false;
  final TokenManager tokenManager;

  ErrorInterceptor getErrorInterceptor() {
    return ErrorInterceptor(
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        if (error.response?.statusCode != 401 || refreshTokenPath == null) {
          return handler.next(error);
        }

        if (_isRefreshing) {
          // Queue the request while refreshing the token
          requestQueue.add(() => _retryRequest(error, handler));
          return;
        }

        _isRefreshing = true;
        try {
          await tokenManager.refreshTokens(refreshTokenPath!);
          await _retryRequest(error, handler);
          // Token, process the request queue
          await requestQueue.processQueue();
        } catch (e) {
          handler.reject(
            DioException(requestOptions: error.requestOptions, error: e),
          );
          // Reject all queued requests
          requestQueue.rejectQueuedRequests();
          } finally {
          _isRefreshing = false;
        }
      },
    );
  }

  Future<void> _retryRequest(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final response = await tokenManager.retryRequest(error.requestOptions);
      handler.resolve(response);
    } catch (e) {
      handler
          .reject(DioException(requestOptions: error.requestOptions, error: e));
    }
  }

}
