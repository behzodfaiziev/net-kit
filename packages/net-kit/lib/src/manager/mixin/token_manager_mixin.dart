part of '../net_kit_manager.dart';

/// Token manager mixin
mixin TokenManagerMixin on DioMixin, RequestManagerMixin, ErrorHandlingMixin {
  /// Implementation of setting the access token
  void setAccessToken(String? token) {
    if (token == null) return;
    baseOptions.headers.addAll({parameters.accessTokenKey: 'Bearer $token'});
  }

  /// Implementation of setting the refresh token
  void setRefreshToken(String? token) {
    if (token == null) return;
    baseOptions.headers.addAll({parameters.refreshTokenKey: token});
  }

  /// Implementation of removing the access token
  void removeAccessToken() {
    baseOptions.headers.remove(parameters.accessTokenKey);
  }

  /// Implementation of removing the refresh token
  void removeRefreshToken() {
    baseOptions.headers.remove(parameters.refreshTokenKey);
  }

  /// Extracts the tokens from the response's headers
  AuthTokenModel extractTokens({
    required Response<dynamic> response,
    required String accessTokenKey,
    required String refreshTokenKey,
  }) {
    // Try to extract tokens from headers
    final accessToken = response.headers.value(accessTokenKey);
    final refreshToken = response.headers.value(refreshTokenKey);
    return AuthTokenModel(accessToken: accessToken, refreshToken: refreshToken);
  }
}
