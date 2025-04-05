import '../../../net_kit.dart';

/// A class that manages the authentication tokens used for
/// API requests, handling token refresh logic and request retries.
///
/// The `TokenManager` class is responsible for retrieving the current
/// refresh token, making requests to refresh the access token,
/// and updating the stored tokens. It also provides functionality
/// to retry original requests after a token refresh.
class TokenManager {
  /// Creates an instance of `TokenManager`.
  ///
  /// The constructor requires the following parameters:
  ///
  /// - [refreshTokenRequest]: A function to make the request for
  ///   refreshing the access token.
  /// - [retryRequest]: A function to retry the original request
  ///   after the token refresh.
  /// - [onTokensUpdated]: An optional callback function that
  ///   is invoked when tokens are updated.
  TokenManager({
    required Future<AuthTokenModel> Function() refreshTokenRequest,
    required Future<Response<dynamic>> Function(RequestOptions requestOptions)
        retryRequest,
    required INetKitLogger? logger,
    required void Function(AuthTokenModel authToken) onTokensUpdated,
  }) {
    _refreshTokenRequest = refreshTokenRequest;
    _retryRequest = retryRequest;
    _onTokensUpdated = onTokensUpdated;
    _logger = logger;
  }

  /// An optional logger for logging token refresh operations.
  late final INetKitLogger? _logger;

  /// A function that makes the request to refresh the access token.
  ///
  /// This function is expected to return an instance of
  /// `AuthTokenModel`, which contains the new access and refresh tokens.
  late final Future<AuthTokenModel> Function() _refreshTokenRequest;

  /// A function that retries the original request after
  /// the token has been refreshed.
  late final Future<Response<dynamic>> Function(RequestOptions requestOptions)
      _retryRequest;

  /// An optional callback function that is invoked when tokens
  /// are updated.
  late final void Function(AuthTokenModel authToken)? _onTokensUpdated;

  /// Refreshes the authentication tokens.
  ///
  /// This method retrieves the current refresh token, makes a
  /// request to refresh the access token, and updates the stored
  /// tokens accordingly. If the tokens are successfully updated,
  /// the optional [_onTokensUpdated] callback is invoked.
  ///
  /// Throws:
  /// - Throws any error encountered during the token refresh
  ///   request, allowing for handling in the calling context.
  Future<void> refreshTokens() async {
    try {
      _logger?.info('Refreshing token...');

      // Make the request to refresh the token
      final authToken = await _refreshTokenRequest();

      _logger?.info('Tokens updated successfully.');

      // Notify that the tokens were updated
      if (_onTokensUpdated != null) {
        _logger?.info('Notifying tokens updated...');
        _onTokensUpdated!.call(authToken);
      }
    } catch (e) {
      _logger?.warning('Token refresh failed: $e');
      // Propagate the error for handling in the interceptor
      rethrow;
    }
  }

  /// Retries the original HTTP request after the token has been refreshed.
  ///
  /// This method takes the original request options and attempts
  /// to retry the request using the `retryRequest` function provided.
  ///
  /// Parameters:
  /// - [requestOptions]: The original request options to be retried.
  ///
  /// Returns:
  /// - Returns the response from the retried request.
  ///
  /// Throws:
  /// - Throws any error encountered during the retry, allowing for
  ///   handling in the calling context.
  Future<Response<dynamic>> retryOriginalRequest(
    RequestOptions requestOptions,
  ) async {
    try {
      // Retry the original request using the injected retry function
      final response = await _retryRequest(requestOptions);
      return response;
    } catch (e) {
      rethrow; // Propagate the error for handling in the interceptor
    }
  }
}
