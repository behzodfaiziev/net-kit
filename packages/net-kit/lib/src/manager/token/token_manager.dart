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
  /// - [requestNewTokens]: A function to make the request for
  ///   refreshing the access token.
  /// - [onTokensUpdated]: An optional callback function that
  ///   is invoked when tokens are updated.
  TokenManager({
    required Future<AuthTokenModel> Function() requestNewTokens,
    required INetKitLogger? logger,
    required void Function(AuthTokenModel authToken) onTokensUpdated,
  })  : _requestNewTokens = requestNewTokens,
        _onTokensUpdated = onTokensUpdated,
        _logger = logger;

  /// An optional logger for logging token refresh operations.
  final INetKitLogger? _logger;

  /// A function that makes the request to refresh the access token.
  ///
  /// This function is expected to return an instance of
  /// `AuthTokenModel`, which contains the new access and refresh tokens.
  final Future<AuthTokenModel> Function() _requestNewTokens;

  /// An optional callback function that is invoked when tokens
  /// are updated.
  final void Function(AuthTokenModel authToken) _onTokensUpdated;

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
      final authToken = await _requestNewTokens();

      _logger?.info('Tokens updated successfully.');

      // Notify that the tokens were updated
      _logger?.info('Notifying tokens updated...');
      _onTokensUpdated.call(authToken);
    } catch (e) {
      _logger?.warning('Token refresh failed: $e');
      // Propagate the error for handling in the interceptor
      rethrow;
    }
  }
}
