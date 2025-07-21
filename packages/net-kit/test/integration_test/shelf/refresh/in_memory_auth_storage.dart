class InMemoryAuthStorage {
  String? accessToken;
  String? refreshToken;

  Future<void> setAccessToken(String token) async => accessToken = token;
  Future<void> setRefreshToken(String token) async => refreshToken = token;
  Future<String?> getAccessToken() async => accessToken;
  Future<String?> getRefreshToken() async => refreshToken;
}
