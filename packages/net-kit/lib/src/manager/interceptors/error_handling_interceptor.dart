part of '../net_kit_manager.dart';

class ErrorHandlingInterceptor {
  final NetKitManager netKitManager;
  final String? refreshTokenPath;

  ErrorHandlingInterceptor({
    required this.netKitManager,
    required this.refreshTokenPath,
  }) {
    _addInterceptor();
  }

  void _addInterceptor() {
    netKitManager.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (error.response?.statusCode == 401 && refreshTokenPath != null) {
            try {
              // Logic to refresh the token
              final refreshResponse = await netKitManager.request<dynamic>(
                refreshTokenPath!,
                options: Options(
                  method: RequestMethod.post.name.toUpperCase(),
                ),
                data: {
                  // Assuming the refresh token is stored in headers
                  netKitManager.parameters.refreshTokenKey:
                      netKitManager._getRefreshToken(),
                },
              );

              // Extract tokens from the response
              final authToken = netKitManager.extractTokens(
                response: refreshResponse,
                accessTokenKey: netKitManager.parameters.accessTokenKey,
                refreshTokenKey: netKitManager.parameters.refreshTokenKey,
              );

              // Update tokens in NetKitManager
              netKitManager
                ..addBearerToken(authToken.accessToken)
                ..addRefreshToken(authToken.refreshToken)

                // Notify listeners about token updates
                ..onTokensUpdated(authToken);

              // Retry the original request
              final response = await netKitManager.request<dynamic>(
                error.requestOptions.path,
                options: Options(
                  method: error.requestOptions.method,
                  headers: error.requestOptions.headers,
                ),
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
              );

              return handler.resolve(response);
            } catch (e) {
              return handler.reject(
                DioException(
                  requestOptions: error.requestOptions,
                  error: e,
                ),
              );
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
}
