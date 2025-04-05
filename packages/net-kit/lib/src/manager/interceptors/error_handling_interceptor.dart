part of '../net_kit_manager.dart';

/// A class that handles error responses in HTTP requests,
/// particularly focusing on token refresh logic when encountering
/// authentication errors (401 status code).
///
/// The `ErrorHandlingInterceptor` works by intercepting errors
/// returned from HTTP requests and managing token refresh requests.
/// It ensures that if a request encounters a 401 error, the token
/// is refreshed before retrying the request, handling concurrent
/// requests appropriately.
class ErrorHandlingInterceptor {
  /// Creates an instance of `ErrorHandlingInterceptor`.
  ///
  /// The constructor requires the following parameters:
  ///
  /// - [refreshTokenPath]: The API endpoint for refreshing the token.
  /// - [requestQueue]: An instance of `RequestQueue` to manage
  ///   queued requests while the token is being refreshed.
  /// - [tokenManager]: An instance of `TokenManager` to handle
  ///   token refresh and retry operations.
  ErrorHandlingInterceptor({
    required this.refreshTokenPath,
    required this.requestQueue,
    required this.tokenManager,
    required this.logger,
  });

  /// The path to the token refresh endpoint.
  final String? refreshTokenPath;

  /// The queue that manages requests waiting for token refresh.
  final RequestQueue requestQueue;

  /// A flag indicating whether a token refresh is currently in progress.
  bool _isRefreshing = false;

  /// An instance of `TokenManager` to handle token management.
  final TokenManager tokenManager;

  /// An optional logger for logging token refresh operations.
  final INetKitLogger? logger;

  /// Returns an `ErrorInterceptor` that defines the behavior
  /// when an error occurs during an HTTP request.
  ///
  /// This interceptor checks for 401 errors and manages the token
  /// refresh flow. If a 401 error is encountered:
  ///
  /// - If a token refresh is already in progress, it queues
  ///   the request to retry once the token refresh is complete.
  /// - If no refresh is in progress, it initiates a token refresh.
  ///
  /// After a successful refresh, the original request is retried,
  /// and any queued requests are processed. If the refresh fails,
  /// all queued requests are rejected.
  ErrorInterceptor getErrorInterceptor() {
    return ErrorInterceptor(
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        // Check if the error is a 401 Unauthorized response.
        if (error.response?.statusCode != 401 || refreshTokenPath == null) {
          logger?.error('Error: ${error.message}');
          return handler.next(error);
        }
        // Check if the error is from the refresh token request
        if (error.requestOptions.path == refreshTokenPath) {
          // If it's from the refresh token path, reject with the error
          logger?.error('refresh token error: ${error.message}');
          handler.reject(error);

          // Reject all queued requests as the token is no longer valid
          requestQueue.rejectQueuedRequests();
          return;
        }

        // If a refresh is already in progress, queue the request.
        if (_isRefreshing) {
          logger?.info('Token refresh in progress, queuing request');
          requestQueue
              .enqueueDuringRefresh(() => _retryRequest(error, handler));
          return;
        }

        _isRefreshing = true;
        try {
          // Refresh the tokens using the token manager.
          await tokenManager.refreshTokens();
          logger?.info('Retrying original request after token refresh');
          // Retry the original request after the tokens are refreshed.
          await _retryRequest(error, handler);

          logger?.info('Token refreshed successfully, '
              'retrying queued requests');
          // Process any queued requests after a successful refresh.
          await requestQueue.processQueue();
        } on DioException catch (e) {
          // Reject the original request if token refresh fails.
          handler.reject(e);
          logger?.error(
            'DioException: Error occurred: ${e.message}',
          );
          // Reject all queued requests due to the failure.
          requestQueue.rejectQueuedRequests();
        } on Exception catch (e) {
          // Reject the original request if token refresh fails.
          handler.reject(
            DioException(requestOptions: error.requestOptions, error: e),
          );
          // Reject all queued requests due to the failure.
          requestQueue.rejectQueuedRequests();
        } finally {
          // Reset the refresh flag.
          logger?.info('Token refresh completed');
          _isRefreshing = false;
        }
      },
    );
  }

  /// Retries the original HTTP request after a successful token refresh.
  ///
  /// This method attempts to resolve the request using the `retryRequest`
  /// method of the `tokenManager`. If the retry is successful, the response
  /// is resolved. If an error occurs during the retry, the error is
  /// rejected through the handler.
  ///
  /// Parameters:
  /// - [error]: The original `DioException` that triggered the retry.
  /// - [handler]: The interceptor handler that manages the request flow.
  Future<void> _retryRequest(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      logger?.info('Retrying original request after token refresh');
      // Attempt to retry the original request.
      final response =
          await tokenManager.retryOriginalRequest(error.requestOptions);
      logger?.info('Original request retried successfully');
      handler.resolve(response);
    } on DioException catch (e) {
      logger?.error(
        'DioException: Error retrying original '
        'request after token refreshed: $e',
      );
      // Reject the request if retry fails.
      rethrow;
    } catch (e) {
      logger?.fatal(
        'Error retrying original request after token refreshed: $e',
      );
      // Reject the request if retry fails.
      rethrow;
    }
  }
}
