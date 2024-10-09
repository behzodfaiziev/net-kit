mixin AuthMixin on NetKitManager {
  // Method to extract access and refresh tokens from the response headers
  AuthTokenModel extractTokens({
    required Response response,
    required String accessTokenKey,
    required String refreshTokenKey,
  }) {
    final String? accessToken = response.headers.value(accessTokenKey);
    final String? refreshToken = response.headers.value(refreshTokenKey);
    return AuthTokenModel(accessToken: accessToken, refreshToken: refreshToken);
  }

  // SignIn Method (Standard authentication)
  Future<(R, AuthTokenModel)> signIn<R extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    MapType? body,
    Options? options,
    String accessTokenKey = 'Authorization',
    String refreshTokenKey = 'Refresh-Token',
  }) async {
    try {
      final response = await _sendRequest(
        path: path,
        method: method,
        body: body,
        options: options,
      );

      // Ensure the response data is a map
      if ((response.data is MapType) == false) {
        throw _notMapTypeError(response);
      }

      final parsedModel = Converter.toModel<R>(response.data as MapType, model);

      // Extract tokens (from headers)
      final authToken = extractTokens(
        response: response,
        accessTokenKey: accessTokenKey,
        refreshTokenKey: refreshTokenKey,
      );

      // Add the tokens to headers for subsequent requests
      addBearerToken(authToken.accessToken);
      addRefreshToken(authToken.refreshToken);

      return (parsedModel, authToken);
    } on DioException catch (error) {
      throw _parseToApiException(error);
    }
  }

  // Social SignIn (OAuth2-based authentication with social platforms)
  Future<(R, AuthTokenModel)> signInWithSocial<R extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    required String socialAccessToken,
    Options? options,
    String accessTokenKey = 'Authorization',
    String refreshTokenKey = 'Refresh-Token',
  }) async {
    try {
      // Attach the social access token to the headers for authentication
      options?.headers['Authorization'] = 'Bearer $socialAccessToken';

      final response = await _sendRequest(
        path: path,
        method: method,
        options: options,
      );

      // Extract the tokens (access and refresh)
      final authToken = extractTokens(
        response: response,
        accessTokenKey: accessTokenKey,
        refreshTokenKey: refreshTokenKey,
      );

      // Add the tokens to headers for future requests
      addBearerToken(authToken.accessToken);
      addRefreshToken(authToken.refreshToken);

      // Parse the response model
      final parsedModel = Converter.toModel<R>(response.data, model);

      return (parsedModel, authToken);
    } on DioException catch (error) {
      throw _parseToApiException(error);
    }
  }

  // SignUp Method (For user registration)
  Future<(R, AuthTokenModel)> signUp<R extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    MapType? body,
    Options? options,
    String accessTokenKey = 'Authorization',
    String refreshTokenKey = 'Refresh-Token',
  }) async {
    try {
      final response = await _sendRequest(
        path: path,
        method: method,
        body: body,
        options: options,
      );

      // Ensure the response data is a map
      if ((response.data is MapType) == false) {
        throw _notMapTypeError(response);
      }

      final parsedModel = Converter.toModel<R>(response.data as MapType, model);

      // Extract tokens (from headers)
      final authToken = extractTokens(
        response: response,
        accessTokenKey: accessTokenKey,
        refreshTokenKey: refreshTokenKey,
      );

      // Optionally add tokens to headers for future requests
      addBearerToken(authToken.accessToken);
      addRefreshToken(authToken.refreshToken);

      return (parsedModel, authToken);
    } on DioException catch (error) {
      throw _parseToApiException(error);
    }
  }
}
