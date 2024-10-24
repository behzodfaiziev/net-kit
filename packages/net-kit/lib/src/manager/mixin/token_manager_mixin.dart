part of '../net_kit_manager.dart';

/// Token manager mixin
mixin TokenManagerMixin on DioMixin, RequestManagerMixin, ErrorHandlingMixin {
  void setAccessToken(String? token) {
    if (token == null) return;
    baseOptions.headers.addAll({parameters.accessTokenKey: 'Bearer $token'});
  }

  void setRefreshToken(String? token) {
    if (token == null) return;
    baseOptions.headers.addAll({parameters.refreshTokenKey: token});
  }

  /// Extracts the tokens from the response
  AuthTokenModel extractTokens({
    required Response<dynamic> response,
    required String accessTokenKey,
    required String refreshTokenKey,
  }) {
    final data = response.data as MapType;

    final accessToken = data[accessTokenKey] as String;
    final refreshToken = data[refreshTokenKey] as String;

    return AuthTokenModel(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}
