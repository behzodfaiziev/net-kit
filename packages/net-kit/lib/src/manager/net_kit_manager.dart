import 'dart:async';

import 'package:dio/dio.dart';

import '../core/net_kit_request_options.dart';
import '../enum/http_status_codes.dart';
import '../enum/request_method.dart';
import '../model/api_meta_response.dart';
import '../model/auth_token_model.dart';
import '../model/i_net_kit_model.dart';
import '../model/void_model.dart';
import '../utility/converter.dart';
import '../utility/file/file_reader.dart';
import '../utility/logger/i_net_kit_logger.dart';
import '../utility/logger/void_logger.dart';
import '../utility/typedef/request_type_def.dart';
import 'adapter/platform_http_adapter.dart';
import 'error/api_exception.dart';
import 'i_net_kit_manager.dart';
import 'interceptors/request_extra_keys.dart';
import 'params/net_kit_error_params.dart';
import 'params/net_kit_params.dart';
import 'queue/request_queue.dart';
import 'token/token_manager.dart';

part 'interceptors/error_handling_interceptor.dart';
part 'mixin/error_handling_mixin.dart';
part 'mixin/request_manager_mixin.dart';
part 'mixin/token_manager_mixin.dart';
part 'mixin/upload_manager_mixin.dart';

/// The NetKitManager class is a network manager that extends DioMixin and
/// implements the INetKitManager interface.
/// It is designed to handle HTTP requests and responses, providing methods to
/// send requests and parse responses into models or lists of models.
/// The class supports various configurations such as base URLs, interceptors
/// and logging. It also includes error handling and
/// response validation mechanisms. The NetKitManager is initialized with
/// parameters that define its behavior and can be used to perform network
/// operations in a structured and consistent manner.
class NetKitManager extends INetKitManager
    with
        DioMixin,
        RequestManagerMixin,
        ErrorHandlingMixin,
        TokenManagerMixin,
        UploadManagerMixin {
  /// The constructor for the NetKitManager class
  NetKitManager({
    /// The base URL for the network requests
    required String baseUrl,

    /// The parameters for error messages and error keys
    NetKitErrorParams? errorParams,

    /// The HTTP client adapter
    HttpClientAdapter? httpClientAdapter,

    /// The development base URL for dev mode
    String? devBaseUrl,

    /// The base options for the network requests
    BaseOptions? baseOptions,

    /// Custom Dio interceptor for the network requests.
    /// Added after `LogInterceptor` (when enabled) and before the built-in
    /// error-handling interceptor.
    Interceptor? interceptor,

    /// The callback function that is called before the refresh token request
    OnBeforeRefresh? onBeforeRefreshRequest,

    /// The callback function that is called when
    /// the refresh token request fails
    OnRefreshFailed? onRefreshFailed,

    /// Whether the network manager is in development mode.
    /// If true, `devBaseUrl` is used instead of `baseUrl`, and logging options
    /// (`loggerEnabled`, `logInterceptorEnabled`) are allowed to take effect.
    /// CAUTION: Make sure that it is set to false in production environments.
    bool devMode = false,

    /// Deprecated. Use `devMode` instead.
    @Deprecated(
      'Use devMode instead. Will be removed in a future major release.',
    )
    bool? testMode,

    /// The stream for the internet status
    Stream<bool>? internetStatusStream,

    /// The key for the access token in the headers
    String accessTokenHeaderKey = 'Authorization',

    /// The key for the access token in the body
    /// Used for automatic token refresh
    String accessTokenBodyKey = 'accessToken',

    /// The prefix for the access token in the headers
    String accessTokenPrefix = 'Bearer',

    /// Whether to remove the access token header before refreshing the token
    /// Default is true
    bool removeAccessTokenBeforeRefresh = true,

    /// The key for the refresh token in the body
    /// Used for automatic token refresh
    String refreshTokenBodyKey = 'refreshToken',

    /// The path for the refresh token request
    String? refreshTokenPath,

    /// The key to extract data from the response.
    /// If null, the response data will be used as is.
    String? dataKey,

    /// The key to extract data from the metadata response.
    /// Default value is ['data']
    String metadataDataKey = 'data',

    /// Logger for the network manager. The default logger is VoidLogger
    /// which does not log anything. To enable logging, a custom logger
    /// must be created and injected into the NetKitManager class.
    INetKitLogger logger = const VoidLogger(),

    /// Whether Dio's `LogInterceptor` is enabled for raw HTTP request/response
    /// logging. Only takes effect when `devMode` is true.
    bool logInterceptorEnabled = false,

    /// Whether the injected `logger` is used for Net-Kit internal logging.
    /// Only takes effect when `devMode` is true.
    bool loggerEnabled = false,

    /// The callback function that is called when the tokens are updated
    OnTokenRefreshed? onTokenRefreshed,

    /// Content type for the refresh token request body.
    RefreshTokenContentType refreshTokenContentType =
        RefreshTokenContentType.json,
  }) {
    final effectiveDevMode = testMode ?? devMode;

    // Initialize the network manager
    _initialize(
      clientAdapter: httpClientAdapter,
      baseUrl: baseUrl,
      errorParams: errorParams,
      devBaseUrl: devBaseUrl,
      baseOptions: baseOptions,
      interceptor: interceptor,
      onBeforeRefreshRequest: onBeforeRefreshRequest,
      onRefreshFailed: onRefreshFailed,
      onTokenRefreshed: onTokenRefreshed,
      devMode: effectiveDevMode,
      logInterceptorEnabled: logInterceptorEnabled,
      loggerEnabled: loggerEnabled,
      logger: logger,
      internetStatusStream: internetStatusStream,
      accessTokenHeaderKey: accessTokenHeaderKey,
      accessTokenBodyKey: accessTokenBodyKey,
      accessTokenPrefix: accessTokenPrefix,
      refreshTokenBodyKey: refreshTokenBodyKey,
      refreshTokenPath: refreshTokenPath,
      removeAccessTokenBeforeRefresh: removeAccessTokenBeforeRefresh,
      dataKey: dataKey,
      metadataDataKey: metadataDataKey,
      refreshTokenContentType: refreshTokenContentType,
    );
  }

  @override
  late final NetKitParams parameters;

  @override
  late final NetKitErrorParams _errorParams;

  @override
  late final INetKitLogger _logger;

  @override
  late final Converter _converter;

  /// This boolean value is used to determine if the internet is enabled
  /// The default value is true, meaning that
  /// the internet is enabled by default.
  /// The value is updated based on the internet status stream.
  @override
  bool _internetEnabled = true;

  @override
  BaseOptions get baseOptions => parameters.baseOptions;

  @override
  Future<R> requestModel<R extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    MapType? body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    ProgressCallback? onSendProgress,
    bool? containsAccessToken,
    bool useDataKey = true,
    bool skipTokenRefresh = false,
    bool allowRetryOn401 = false,
    String? idempotencyKey,
  }) async {
    try {
      _logger.debug(
        'Requesting model: $R at path: $path with method: $method',
      );
      final response = await _sendRequest(
        path: path,
        method: method,
        body: body,
        options: options,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
        containsAccessToken: containsAccessToken,
        skipTokenRefresh: skipTokenRefresh,
        allowRetryOn401: allowRetryOn401,
        idempotencyKey: idempotencyKey,
      );

      _logger.debug('Response received from $path: ${response.data}');

      if (_hasEmptyResponseBody(response)) {
        throw _parseToApiException(_emptyResponseBodyError(response));
      }

      if ((response.data is MapType) == false) {
        throw _notMapTypeError(response);
      }

      final data = useDataKey && parameters.dataKey != null
          ? (response.data as MapType)[parameters.dataKey]
          : response.data;

      final parsedModel = _converter.toModel<R>(data as MapType, model);

      return parsedModel;
    } on DioException catch (error) {
      throw _parseToApiException(error);
    }
  }

  @override
  Future<ApiMetaResponse<R, M>>
      requestModelMeta<R extends INetKitModel, M extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    required M metadataModel, // Add required metadata model
    MapType? body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    ProgressCallback? onSendProgress,
    bool? containsAccessToken,
    bool useDataKey = true,
    bool skipTokenRefresh = false,
    bool allowRetryOn401 = false,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _sendRequest(
        path: path,
        method: method,
        body: body,
        options: options,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
        containsAccessToken: containsAccessToken,
        skipTokenRefresh: skipTokenRefresh,
        allowRetryOn401: allowRetryOn401,
        idempotencyKey: idempotencyKey,
      );

      if (_hasEmptyResponseBody(response)) {
        throw _parseToApiException(_emptyResponseBodyError(response));
      }

      final split = _splitMetaResponse(
        response.data as MapType,
        useDataKey: useDataKey,
      );

      // Parse both models
      final parsedData = _converter.toModel<R>(split.data as MapType, model);
      final parsedMetadata =
          _converter.toModel<M>(split.metadata, metadataModel);

      return ApiMetaResponse(data: parsedData, metadata: parsedMetadata);
    } on DioException catch (error) {
      throw _parseToApiException(error);
    }
  }

  @override
  Future<List<R>> requestList<R extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    MapType? body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    ProgressCallback? onSendProgress,
    bool? containsAccessToken,
    bool useDataKey = true,
    bool skipTokenRefresh = false,
    bool allowRetryOn401 = false,
    String? idempotencyKey,
  }) async {
    try {
      _logger.debug(
        'Requesting list of model: $R at path: $path with method: $method',
      );
      final response = await _sendRequest(
        path: path,
        method: method,
        body: body,
        options: options,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
        containsAccessToken: containsAccessToken,
        skipTokenRefresh: skipTokenRefresh,
        allowRetryOn401: allowRetryOn401,
        idempotencyKey: idempotencyKey,
      );

      _logger.debug('Response received from $path: ${response.data}');

      if (_hasEmptyResponseBody(response)) {
        throw _parseToApiException(_emptyResponseBodyError(response));
      }

      final data = useDataKey && parameters.dataKey != null
          ? (response.data as MapType)[parameters.dataKey]
          : response.data;

      return _converter.toListModel(
        data: data,
        parsingModel: model,
      );
    } on DioException catch (error) {
      throw _parseToApiException(error);
    }
  }

  @override
  Future<ApiMetaResponse<List<R>, M>>
      requestListMeta<R extends INetKitModel, M extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    required M metadataModel, // Add required metadata model
    MapType? body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    ProgressCallback? onSendProgress,
    bool? containsAccessToken,
    bool useDataKey = true,
    bool skipTokenRefresh = false,
    bool allowRetryOn401 = false,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _sendRequest(
        path: path,
        method: method,
        body: body,
        options: options,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
        containsAccessToken: containsAccessToken,
        skipTokenRefresh: skipTokenRefresh,
        allowRetryOn401: allowRetryOn401,
        idempotencyKey: idempotencyKey,
      );

      if (_hasEmptyResponseBody(response)) {
        throw _parseToApiException(_emptyResponseBodyError(response));
      }

      final split = _splitMetaResponse(
        response.data as MapType,
        useDataKey: useDataKey,
      );

      // Parse both models
      final parsedList = _converter.toListModel(
        data: split.data,
        parsingModel: model,
      );

      final parsedMetadata =
          _converter.toModel<M>(split.metadata, metadataModel);

      return ApiMetaResponse(data: parsedList, metadata: parsedMetadata);
    } on DioException catch (error) {
      throw _parseToApiException(error);
    }
  }

  @override
  Future<void> requestVoid({
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
    try {
      await _sendRequest(
        path: path,
        method: method,
        body: body,
        options: options,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
        containsAccessToken: containsAccessToken,
        skipTokenRefresh: skipTokenRefresh,
        allowRetryOn401: allowRetryOn401,
        idempotencyKey: idempotencyKey,
      );

      return;
    } on DioException catch (error) {
      /// Parse the API exception and throw it
      throw _parseToApiException(error);
    }
  }

  @override
  Future<R> uploadMultipartData<R extends INetKitModel>({
    required String path,

    /// The model to parse the data to
    required R model,
    required MultipartFile multipartFile,
    required RequestMethod method,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    String? contentType,
    bool useDataKey = true,
  }) async {
    try {
      return await _uploadMultipartData(
        path: path,
        model: model,
        multipartFile: multipartFile,
        method: method,
        options: options,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
        contentType: contentType,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        useDataKey: useDataKey,
      );
    } on DioException catch (error) {
      throw _parseToApiException(error);
    } on ApiException catch (_) {
      rethrow;
    } on Exception catch (e) {
      throw ApiException(
        message: e.toString(),
        statusCode: HttpStatuses.internalServerError.code,
        error: e,
      );
    }
  }

  @override
  Future<R> uploadFormData<R extends INetKitModel>({
    required String path,
    required R model,
    required FormData formData,
    required RequestMethod method,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    String? contentType,
    bool useDataKey = true,
  }) async {
    try {
      return await _uploadFormData(
        path: path,
        model: model,
        formData: formData,
        method: method,
        options: options,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
        contentType: contentType,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        useDataKey: useDataKey,
      );
    } on DioException catch (error) {
      throw _parseToApiException(error);
    } on ApiException catch (_) {
      rethrow;
    } on Exception catch (e) {
      throw ApiException(
        message: e.toString(),
        statusCode: HttpStatuses.internalServerError.code,
      );
    }
  }

  @override
  Future<R> uploadRawData<R extends INetKitModel>({
    required String path,
    required R model,
    required List<int> data,
    required RequestMethod method,
    String contentType = 'application/octet-stream',
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    bool useDataKey = true,
  }) async {
    try {
      return await _uploadRawData(
        path: path,
        model: model,
        data: data,
        method: method,
        contentType: contentType,
        options: options,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        useDataKey: useDataKey,
      );
    } on DioException catch (error) {
      throw _parseToApiException(error);
    } on ApiException catch (_) {
      rethrow;
    } on Exception catch (e) {
      throw ApiException(
        message: e.toString(),
        statusCode: HttpStatuses.internalServerError.code,
        error: e,
      );
    }
  }

  @override
  Future<R> uploadFile<R extends INetKitModel>({
    required String path,
    required R model,
    required String filePath,
    required RequestMethod method,
    String contentType = 'application/octet-stream',
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    bool useDataKey = true,
  }) async {
    try {
      final bytes = await readFileAsBytes(filePath);
      return await _uploadRawData(
        path: path,
        model: model,
        data: bytes,
        method: method,
        contentType: contentType,
        options: options,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        useDataKey: useDataKey,
      );
    } on DioException catch (error) {
      throw _parseToApiException(error);
    } on ApiException catch (_) {
      rethrow;
    } on Exception catch (e) {
      throw ApiException(
        message: e.toString(),
        statusCode: HttpStatuses.internalServerError.code,
        error: e,
      );
    }
  }

  void _initialize({
    required String baseUrl,
    required bool devMode,
    required String accessTokenHeaderKey,
    required String accessTokenBodyKey,
    required String accessTokenPrefix,
    required String refreshTokenBodyKey,
    required String? refreshTokenPath,
    required bool removeAccessTokenBeforeRefresh,
    required INetKitLogger logger,
    required bool loggerEnabled,
    required bool logInterceptorEnabled,
    required String metadataDataKey,
    required String? dataKey,
    required NetKitErrorParams? errorParams,
    required OnBeforeRefresh? onBeforeRefreshRequest,
    required OnRefreshFailed? onRefreshFailed,
    required OnTokenRefreshed? onTokenRefreshed,
    required String? devBaseUrl,
    required BaseOptions? baseOptions,
    required Interceptor? interceptor,
    required HttpClientAdapter? clientAdapter,
    required Stream<bool>? internetStatusStream,
    RefreshTokenContentType refreshTokenContentType =
        RefreshTokenContentType.json,
  }) {
    /// Set up the base options if not provided
    /// Making sure the BaseOptions is not null
    baseOptions ??= BaseOptions();

    _errorParams = errorParams ?? const NetKitErrorParams();

    parameters = NetKitParams(
      baseOptions: baseOptions,
      interceptor: interceptor,
      devMode: devMode,
      accessTokenHeaderKey: accessTokenHeaderKey,
      accessTokenBodyKey: accessTokenBodyKey,
      accessTokenPrefix: accessTokenPrefix,
      refreshTokenBodyKey: refreshTokenBodyKey,
      onBeforeRefreshRequest: onBeforeRefreshRequest,
      onRefreshFailed: onRefreshFailed,
      onTokenRefreshed: onTokenRefreshed,
      metadataDataKey: metadataDataKey,
      dataKey: dataKey,
      refreshTokenPath: refreshTokenPath,
      removeAccessTokenBeforeRefresh: removeAccessTokenBeforeRefresh,
      refreshTokenContentType: refreshTokenContentType,
      internetStatusSubscription: internetStatusStream?.listen(
        (event) {
          /// Update the internet status when the stream emits a new value
          _internetEnabled = event;
        },
      ),
    );

    /// Initialize the logger
    _logger = loggerEnabled && devMode ? logger : const VoidLogger();

    /// Add log interceptor when enabled and dev mode is true.
    if (logInterceptorEnabled && devMode) {
      interceptors.add(LogInterceptor());
    }

    if (parameters.interceptor != null) {
      interceptors.add(parameters.interceptor!);
    }

    /// Initialize the converter
    _converter = const Converter();

    /// Set up the http client adapter
    httpClientAdapter = clientAdapter ?? createPlatformAdapter().getAdapter();

    /// If dev mode is enabled, use devBaseUrl
    parameters.devMode
        ? parameters.baseOptions.baseUrl = devBaseUrl ?? baseUrl
        : parameters.baseOptions.baseUrl = baseUrl;

    /// Set up the network manager
    options = parameters.baseOptions;

    final errorInterceptor = ErrorHandlingInterceptor(
      refreshTokenPath: parameters.refreshTokenPath,
      logger: _logger,
      retryRequest: _retryRequest,
      onRefreshFailed: parameters.onRefreshFailed,
      requestQueue: RequestQueue(logger: _logger),
      tokenManager: TokenManager(
        requestNewTokens: _requestNewTokens,
        onTokensUpdated: _onTokensUpdated,
        logger: _logger,
      ),
      errorParams: _errorParams,
      accessTokenHeaderKey: parameters.accessTokenHeaderKey,
    ).getErrorInterceptor();

    interceptors.add(errorInterceptor);
  }

  @override
  Map<String, dynamic> getAllHeaders() {
    return baseOptions.headers;
  }

  @override
  void addHeader(MapEntry<String, String> mapEntry) {
    baseOptions.headers.addAll({mapEntry.key: mapEntry.value});
  }

  @override
  void clearAllHeaders() {
    baseOptions.headers.clear();
  }

  @override
  void removeHeader(String key) {
    baseOptions.headers.remove(key);
  }

  @override
  void dispose() {
    httpClientAdapter.close(force: true);
    parameters.internetStatusSubscription?.cancel();
  }

  @override
  void setAccessToken(String? token) {
    _setAccessToken(token);
  }

  @override
  void setRefreshToken(String? token) {
    _setRefreshToken(token);
  }

  @override
  void removeRefreshToken() {
    _removeRefreshToken();
  }

  @override
  void removeAccessToken() {
    _removeAccessToken();
  }

  /// Method to be called when the tokens are updated.
  /// Calls the onTokenRefreshed callback if provided.
  /// The callback function is optional and can be set w
  /// hen initializing the network manager.
  void _onTokensUpdated(AuthTokenModel authToken) {
    // Call the callback if provided
    parameters.onTokenRefreshed?.call(authToken);

    _setAccessToken(authToken.accessToken);

    // Sets the refresh token if it is not null
    if (authToken.refreshToken != null) {
      _setRefreshToken(authToken.refreshToken);
    }
  }

  /// Splits a meta response into payload data and metadata without mutating
  /// the original response map.
  ({dynamic data, MapType metadata}) _splitMetaResponse(
    MapType responseData, {
    required bool useDataKey,
  }) {
    final container = useDataKey && parameters.dataKey != null
        ? responseData[parameters.dataKey] as MapType
        : responseData;

    final copy = Map<String, dynamic>.from(container);
    final data = copy.remove(parameters.metadataDataKey);
    return (data: data, metadata: copy);
  }

  /// Method to send a request to the server to refresh the access token.
  Future<AuthTokenModel> _requestNewTokens() async {
    if (parameters.refreshTokenPath == null) {
      throw ApiException(
        message: 'Refresh token path is not set.',
        statusCode: HttpStatuses.internalServerError.code,
      );
    }

    /// Removes the access token from the headers,
    /// if specified in the parameters
    if (parameters.removeAccessTokenBeforeRefresh) {
      _removeAccessToken();
    }

    final options = NetKitRequestOptions(
      method: RequestMethod.post.name.toUpperCase(),
      path: parameters.refreshTokenPath!,
      headers: parameters.baseOptions.headers,
      contentType: parameters.baseOptions.contentType,
      data: {parameters.refreshTokenBodyKey: _refreshToken},
    );

    parameters.onBeforeRefreshRequest?.call(options);

    await Future<void>.delayed(Duration.zero);

    if (!_internetEnabled) {
      throw ApiException(
        message: _errorParams.noInternetError,
        statusCode: HttpStatuses.serviceUnavailable.code,
      );
    }

    final refreshContentType = parameters.refreshTokenContentType ==
            RefreshTokenContentType.formUrlEncoded
        ? Headers.formUrlEncodedContentType
        : options.contentType;

    final refreshResponse = await request<dynamic>(
      options.path,
      options: Options(
        method: options.method,
        headers: options.headers,
        responseType: ResponseType.json,
        contentType: refreshContentType,
        extra: {RequestExtraKeys.isRefreshRequest: true},
      ),
      data: options.data,
    );

    return _requireValidRefreshTokens(refreshResponse);
  }

  AuthTokenModel _requireValidRefreshTokens(Response<dynamic> response) {
    if (_isRequestFailed(response.statusCode)) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        stackTrace: StackTrace.current,
      );
    }

    final tokens = extractTokens(response: response);
    if (tokens.accessToken == null || tokens.accessToken!.isEmpty) {
      throw ApiException(
        message: _errorParams.invalidTokenResponseError,
        statusCode: response.statusCode ?? HttpStatuses.expectationFailed.code,
      );
    }

    return tokens;
  }
}
