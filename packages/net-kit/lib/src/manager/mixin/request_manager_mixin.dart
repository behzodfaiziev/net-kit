part of '../net_kit_manager.dart';

/// Mixin for request manager
mixin RequestManagerMixin on DioMixin {
  /// The error params for the network manager
  NetKitErrorParams get _errorParams;

  /// The parameters for the network manager
  NetKitParams get parameters;

  /// The logger for the network manager
  INetKitLogger get _logger;

  /// Whether the internet is enabled
  bool get _internetEnabled;

  /// The converter for the network manager
  Converter get _converter;

  /// Sends a request to the server
  Future<Response<dynamic>> _sendRequest({
    required String path,
    required RequestMethod method,
    MapType? body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    ProgressCallback? onSendProgress,
    bool? containsAccessToken,
    bool skipTokenRefresh = false,
    bool allowRetryOn401 = false,
    String? idempotencyKey,
  }) async {
    if (!_internetEnabled) {
      throw ApiException(
        message: _errorParams.noInternetError,
        statusCode: HttpStatuses.serviceUnavailable.code,
      );
    }

    options ??= Options();
    options.method = method.name.toUpperCase();
    options.headers ??= {};

    if (containsAccessToken == false) {
      options.headers![parameters.accessTokenHeaderKey] = null;
    }

    options.extra = Map<String, dynamic>.from(options.extra ?? const {});
    if (skipTokenRefresh) {
      options.extra![RequestExtraKeys.skipTokenRefresh] = true;
    }
    if (allowRetryOn401) {
      options.extra![RequestExtraKeys.allowRetryOn401] = true;
    }
    if (idempotencyKey != null) {
      options.extra![RequestExtraKeys.idempotencyKey] = idempotencyKey;
      options.headers!['Idempotency-Key'] = idempotencyKey;
    }
    if (onSendProgress != null) {
      options.extra![RequestExtraKeys.onSendProgress] = onSendProgress;
    }
    if (onReceiveProgress != null) {
      options.extra![RequestExtraKeys.onReceiveProgress] = onReceiveProgress;
    }

    return request<dynamic>(
      path,
      data: body,
      options: options,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      onSendProgress: onSendProgress,
    );
  }

  /// Retries a request with the given request options
  Future<Response<dynamic>> _retryRequest(RequestOptions requestOptions) async {
    final mergedHeaders = Map<String, dynamic>.from(parameters.baseOptions.headers)
      ..addAll(requestOptions.headers)
      ..remove(parameters.accessTokenHeaderKey);
    if (parameters.baseOptions.headers[parameters.accessTokenHeaderKey] !=
        null) {
      mergedHeaders[parameters.accessTokenHeaderKey] =
          parameters.baseOptions.headers[parameters.accessTokenHeaderKey];
    }

    final retryOptions = requestOptions.copyWith(
      headers: mergedHeaders,
      cancelToken: requestOptions.cancelToken,
      data: requestOptions.data is FormData
          ? (requestOptions.data as FormData).clone()
          : requestOptions.data,
    );

    final response = await fetch<dynamic>(retryOptions);

    if (_isRequestFailed(response.statusCode)) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        stackTrace: StackTrace.current,
      );
    }

    return response;
  }

  /// Checks if the request failed based on the status code
  bool _isRequestFailed(int? statusCode) {
    if (statusCode == null) {
      return true;
    }

    return statusCode < HttpStatuses.ok.code ||
        statusCode >= HttpStatuses.multipleChoices.code;
  }

  bool _hasEmptyResponseBody(Response<dynamic> response) {
    if (response.statusCode == HttpStatuses.noContent.code) {
      return true;
    }

    final data = response.data;
    if (data == null) {
      return true;
    }

    if (data is String && data.isEmpty) {
      return true;
    }

    if (data is List && data.isEmpty) {
      return true;
    }

    return false;
  }

  DioException _emptyResponseBodyError(Response<dynamic> response) {
    return DioException(
      requestOptions: response.requestOptions,
      response: Response<dynamic>(
        requestOptions: response.requestOptions,
        statusCode: response.statusCode,
        data: {
          _errorParams.messageKey: _errorParams.emptyResponseBodyError,
          _errorParams.statusCodeKey: response.statusCode,
        },
      ),
    );
  }
}
