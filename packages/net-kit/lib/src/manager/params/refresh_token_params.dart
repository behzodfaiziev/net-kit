/// This class is the configuration of how the refresh token should be handled
class RefreshTokenParams {
  /// Constructor for the refresh token parameters
  const RefreshTokenParams({
    this.headers,
    this.body,
    this.refreshTokenPath,
  });

  /// Custom headers to be sent during token refresh
  final Map<String, String>? headers;

  /// Custom body to be sent during token refresh
  final Map<String, dynamic>? body;

  /// The path for the refresh token request
  final String? refreshTokenPath;
}
