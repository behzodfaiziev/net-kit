class AuthTokenModel{
  const AuthTokenModel({
    this.accessToken,
    this.refreshToken
  });

  final String? accessToken;
  final String? refreshToken;

}