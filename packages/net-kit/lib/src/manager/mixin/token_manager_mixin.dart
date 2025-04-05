part of '../net_kit_manager.dart';

/// Token manager mixin
mixin TokenManagerMixin on DioMixin, RequestManagerMixin, ErrorHandlingMixin {
  String? _refreshToken;

  /// Implementation of setting the access token
  void _setAccessToken(String? token) {
    if (token == null) return;
    baseOptions.headers.addAll(
      {
        parameters.accessTokenHeaderKey:
            '${parameters.accessTokenPrefix} $token',
      },
    );
  }

  /// Implementation of setting the refresh token
  void _setRefreshToken(String? token) {
    if (token == null) return;
    _refreshToken = token;
  }

  /// Implementation of removing the access token
  void _removeAccessToken() {
    baseOptions.headers.remove(parameters.accessTokenHeaderKey);
  }

  /// Implementation of removing the refresh token
  void _removeRefreshToken() {
    _refreshToken = null;
  }

  /// Extracts the tokens from the response's headers
  AuthTokenModel extractTokens({required Response<dynamic> response}) {
    try {
      if ((response.statusCode ?? 0) >= 500) {
        return const AuthTokenModel();
      }

      // Ensure response.data is treated as a Map
      final data = (parameters.dataKey != null
          ? (response.data as MapType)[parameters.dataKey]
          : response.data) as MapType?;

      if (data == null) {
        return const AuthTokenModel();
      }

      return AuthTokenModel(
        accessToken: data[parameters.accessTokenBodyKey] as String?,
        refreshToken: data[parameters.refreshTokenBodyKey] as String?,
      );
    } on Object catch (_) {
      return const AuthTokenModel();
    }
  }
}
