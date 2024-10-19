import '../../../net_kit.dart';

class TokenManager {
  TokenManager({
    required this.getRefreshToken,
    required this.addBearerToken,
    required this.addRefreshToken,
    required this.refreshTokenRequest,
    required this.retryRequest, // Added this
    this.onTokensUpdated,
  });

  final String Function() getRefreshToken;
  final void Function(String accessToken) addBearerToken;
  final void Function(String refreshToken) addRefreshToken;
  final Future<AuthTokenModel> Function(
    String refreshTokenPath,
    String refreshToken,
  ) refreshTokenRequest;
  final Future<Response<dynamic>> Function(RequestOptions requestOptions)
      retryRequest; // Added this
  final void Function(AuthTokenModel authToken)? onTokensUpdated;

  Future<void> refreshTokens(String refreshTokenPath) async {
    try {
      // Retrieve the current refresh token
      final refreshToken = getRefreshToken();

      // Make the request to refresh the token
      final authToken =
          await refreshTokenRequest(refreshTokenPath, refreshToken);

      // Update the tokens using the provided functions
      addBearerToken(authToken.accessToken ?? '');
      addRefreshToken(authToken.refreshToken ?? '');

      // Notify that the tokens were updated
      if (onTokensUpdated != null) {
        onTokensUpdated!.call(authToken);
      }
    } catch (e) {
      // Propagate the error for handling in the interceptor
      rethrow;
    }
  }

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
