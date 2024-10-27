part of '../net_kit_manager.dart';

/// Mixin for authentication manager
mixin AuthenticationManagerMixin
    on DioMixin, RequestManagerMixin, ErrorHandlingMixin, TokenManagerMixin {
  Future<(R, AuthTokenModel)> _authenticate<R extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    MapType? body,
    Options? options,
    String? socialAccessToken, // Optional social access token for social login
  }) async {
    try {
      // If it's a social login, attach the social access token to the headers
      if (socialAccessToken != null) {
        options ??= Options(); // Ensure options is not null
        options.headers ??= {}; // Ensure headers is not null
        options.headers![parameters.accessTokenKey] =
            'Bearer $socialAccessToken';
      }

      final response = await _sendRequest(
        path: path,
        method: method,
        body: body,
        options: options,
        containsAccessToken: true,
      );

      // If the response data is not a MapType and the model is not a VoidModel
      // then throw an error
      if ((response.data is MapType) == false && model is! VoidModel) {
        throw _notMapTypeError(response);
      }

      // Extract the tokens (access and refresh)
      final authToken = extractTokens(
        response: response,
        accessTokenKey: parameters.accessTokenKey,
        refreshTokenKey: parameters.refreshTokenKey,
      );

      // Add the tokens to headers for subsequent requests
      setAccessToken(authToken.accessToken);
      setRefreshToken(authToken.refreshToken);

      // Parse the response model
      final parsedModel =
          _converter.toModel<R>(response.data as MapType, model);

      return (parsedModel, authToken);
    } on DioException catch (error) {
      // Handle DioException errors
      throw _parseToApiException(error);
    }
  }
}
