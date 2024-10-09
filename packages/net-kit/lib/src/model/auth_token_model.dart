/// Model for the auth token.
/// It contains the access token and the refresh token.
class AuthTokenModel {
  /// The constructor for the AuthTokenModel class
  const AuthTokenModel({
    this.accessToken,
    this.refreshToken,
  });

  /// The access token
  final String? accessToken;

  /// The refresh token
  final String? refreshToken;
}
