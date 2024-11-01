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
  /// - [getRefreshToken]: A function to retrieve the current refresh token.
  /// - [addBearerToken]: A function to store the new access token.
  /// - [addRefreshToken]: A function to store the new refresh token.
  /// - [refreshTokenRequest]: A function to make the request for
  ///   refreshing the access token.
  /// - [retryRequest]: A function to retry the original request
  ///   after the token refresh.
  /// - [onTokensUpdated]: An optional callback function that
  ///   is invoked when tokens are updated.
  TokenManager({
    required this.addBearerToken,
    required this.addRefreshToken,
    required this.refreshTokenRequest,
    required this.retryRequest, // Added this
    this.onTokensUpdated,
    this.logger,
  });

  /// A function that stores the new access token.
  final void Function(String accessToken) addBearerToken;

  /// A function that stores the new refresh token.
  final void Function(String refreshToken) addRefreshToken;

  /// An optional logger for logging token refresh operations.
  final INetKitLogger? logger;

  /// A function that makes the request to refresh the access token.
  ///
  /// This function is expected to return an instance of
  /// `AuthTokenModel`, which contains the new access and refresh tokens.
  final Future<AuthTokenModel> Function(String refreshTokenPath)
      refreshTokenRequest;

  /// A function that retries the original request after
  /// the token has been refreshed.
  final Future<Response<dynamic>> Function(RequestOptions requestOptions)
      retryRequest;

  /// An optional callback function that is invoked when tokens
  /// are updated.
  final void Function(AuthTokenModel authToken)? onTokensUpdated;

  /// Refreshes the authentication tokens.
  ///
  /// This method retrieves the current refresh token, makes a
  /// request to refresh the access token, and updates the stored
  /// tokens accordingly. If the tokens are successfully updated,
  /// the optional [onTokensUpdated] callback is invoked.
  ///
  /// Parameters:
  /// - [refreshTokenPath]: The API endpoint for refreshing the token.
  ///
  /// Throws:
  /// - Throws any error encountered during the token refresh
  ///   request, allowing for handling in the calling context.
  Future<void> refreshTokens(String refreshTokenPath) async {
    try {
      logger?.info('Refreshing token...');

      // Make the request to refresh the token
      final authToken = await refreshTokenRequest(refreshTokenPath);

      logger?.info('Token refreshed successfully.');

      // Update the tokens using the provided functions
      addBearerToken(authToken.accessToken ?? '');
      addRefreshToken(authToken.refreshToken ?? '');

      logger?.info('Tokens updated successfully.');

      // Notify that the tokens were updated

      if (onTokensUpdated != null) {
        logger?.info('Notifying tokens updated...');
        onTokensUpdated!.call(authToken);
      }
    } catch (e) {
      logger?.warning('Token refresh failed: $e');
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
      final response = await retryRequest(requestOptions);
      return response;
    } catch (e) {
      rethrow; // Propagate the error for handling in the interceptor
    }
  }
}
