part of '../net_kit_manager.dart';

/// Mixin for request manager
mixin RequestManagerMixin on DioMixin {
  /// Overridden parameters getter
  NetKitParams get parameters;

  /// Overridden errorParams getter
  NetKitErrorParams get _errorParams;

  /// Overridden internetEnabled getter
  bool get _internetEnabled;

  /// Overridden converter getter
  Converter get _converter;

  /// Overridden baseOptions getter
  BaseOptions get baseOptions;

  Future<Response<dynamic>> _sendRequest({
    required String path,
    required RequestMethod method,
    bool? containsAccessToken,
    MapType? body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    ProgressCallback? onSendProgress,
  }) async {
    // Preserved access token. Used when the access token is removed
    // from the headers and needs to be set back after the request
    String? accessToken;
    try {
      if (!_internetEnabled) {
        throw ApiException(
          message: _errorParams.noInternetError,
          statusCode: HttpStatuses.serviceUnavailable.code,
        );
      }

      options ??= Options();

      // Set the request method
      options.method = method.name.toUpperCase();

      // Remove the access token from the headers if it's not needed.
      if (containsAccessToken == false &&
          options.headers?[parameters.accessTokenKey] != null) {
        // Preserve the access token to set it back after the request
        accessToken = options.headers?[parameters.accessTokenKey] as String;
        // Remove the access token from the headers
        baseOptions.headers.remove(parameters.accessTokenKey);
      }

      final response = await request<dynamic>(
        path,
        data: body,
        options: options,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );

      if (_isRequestFailed(response.statusCode)) {
        // Throw an exception if the request failed
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          stackTrace: StackTrace.current,
        );
      }
      return response;
    } on DioException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        message: error.toString(),
        statusCode: HttpStatuses.expectationFailed.code,
      );
    } finally {
      // Set the access token back to the headers if it was removed
      if (accessToken != null && containsAccessToken == false) {
        baseOptions.headers[parameters.accessTokenKey] = accessToken;
      }
    }
  }

  /// Check if the request failed
  /// If the status code is null or not in the range of 200-299, return true
  /// Otherwise, return false
  bool _isRequestFailed(int? statusCode) {
    // If the status code is null, return true (request failed)
    if (statusCode == null) return true;

    // If the status code is not in the range of 200-299,
    // return true (request failed)
    return statusCode < HttpStatuses.ok.code ||
        statusCode >= HttpStatuses.multipleChoices.code;
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions requestOptions) async {
    // Check if the request's body is FormData
    if (requestOptions.data is FormData && requestOptions.data != null) {
      final formData = requestOptions.data as FormData;
      final newFormData = formData.clone();
      requestOptions.data = newFormData;
    }
    return request<dynamic>(
      requestOptions.path,
      options: Options(
        method: requestOptions.method,
        // Make sure to add the new access token to the headers
        headers: baseOptions.headers,
      ),
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
    );
  }
}
