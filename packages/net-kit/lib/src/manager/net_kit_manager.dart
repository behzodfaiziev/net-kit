import 'package:dio/dio.dart';

import '../enum/http_status_codes.dart';
import '../enum/log_level.dart';
import '../enum/request_method.dart';
import '../model/auth_token_model.dart';
import '../model/error_interceptor.dart';
import '../model/i_net_kit_model.dart';
import '../utility/converter.dart';
import '../utility/typedef/request_type_def.dart';
import 'adapter/io_http_adapter.dart'
if (dart.library.html) 'adapter/web_http_adapter.dart' as adapter;
import 'error/api_exception.dart';
import 'i_net_kit_manager.dart';
import 'logger/i_net_kit_logger.dart';
import 'logger/net_kit_logger.dart';
import 'params/net_kit_error_params.dart';
import 'params/net_kit_params.dart';
import 'queue/request_queue.dart';
import 'token/token_manager.dart';

part 'error/error_handler.dart';
part 'interceptors/error_handling_interceptor.dart';
part 'mixin/request_manager_mixin.dart';
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
class NetKitManager extends ErrorHandler
    with DioMixin, RequestManagerMixin, UploadManagerMixin
    implements INetKitManager {
  /// The constructor for the NetKitManager class
  NetKitManager({
    /// The base URL for the network requests
    required String baseUrl,

    /// The parameters for error messages and error keys
    super.errorParams,

    /// The HTTP client adapter
    HttpClientAdapter? httpClientAdapter,

    /// The development base URL for test mode
    String? devBaseUrl,

    /// The base options for the network requests
    BaseOptions? baseOptions,

    /// The interceptor for the network requests
    Interceptor? interceptor,

    /// Whether the network manager is in test mode
    /// If true, the devBaseUrl will be used,
    /// otherwise the baseUrl will be used
    /// CAUTION: Make sure that it is set to false in production environments
    bool testMode = false,

    /// Whether the logger is enabled for Dio requests,
    /// Note: This is independent of the ['logLevel'] parameter,
    bool loggerEnabled = false,

    /// Set the log level for the network manager.
    /// Note: This is independent of the ['loggerEnabled'] parameter,
    /// and will only affect the log level of the network manager.
    /// The default value is [LogLevel.off].
    LogLevel logLevel = LogLevel.off,

    /// The stream for the internet status
    Stream<bool>? internetStatusStream,
    String accessTokenKey = 'Authorization',
    String refreshTokenKey = 'Refresh-Token',
    String? refreshTokenPath,
    this.onTokenRefreshed,
  }) {
    /// Initialize the network manager
    _initialize(
      clientAdapter: httpClientAdapter,
      baseUrl: baseUrl,
      devBaseUrl: devBaseUrl,
      baseOptions: baseOptions,
      interceptor: interceptor,
      testMode: testMode,
      loggerEnabled: loggerEnabled,
      logLevel: logLevel,
      internetStatusStream: internetStatusStream,
      accessTokenKey: accessTokenKey,
      refreshTokenKey: refreshTokenKey,
      refreshTokenPath: refreshTokenPath,
    );
  }

  @override
  late final NetKitParams parameters;

  /// The callback function that is called when the tokens are updated
  /// This function can be used to update the tokens in the app
  /// or perform any other actions that are required when the tokens are updated
  /// The callback function is optional and can be
  /// set when initializing the network manager
  /// Example:
  /// ```dart
  /// final netKitManager = NetKitManager(
  ///  baseUrl: 'https://api.example.com',
  ///  onTokenRefreshed: (authToken) {
  ///  // Update the tokens in the app
  ///  },
  ///  );
  ///  ```
  ///  The callback function takes an [AuthTokenModel] as a parameter
  ///  which contains the access token and refresh token.
  ///  The callback function is called when the tokens are updated
  ///  after a successful refresh token request.
  ///  The callback function is optional and can
  ///  be set when initializing the network manager.

  late final void Function(AuthTokenModel)? onTokenRefreshed;

  late final INetKitLogger _logger;

  late final Converter _converter;

  /// This boolean value is used to determine if the internet is enabled
  /// The default value is true, meaning that
  /// the internet is enabled by default.
  /// The value is updated based on the internet status stream.
  bool _internetEnabled = true;

  @override
  bool get internetEnabled => _internetEnabled;

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
      );

      /// Check if the response data is a map
      /// If not, throw an exception
      if ((response.data is MapType) == false) {
        throw _notMapTypeError(response);
      }
      final parsedModel = Converter.toModel<R>(response.data as MapType, model);

      return parsedModel;
    } on DioException catch (error) {
      /// Parse the API exception and throw it
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
      );
      return _converter.toListModel(
        data: response.data,
        parseModel: model,
      );
    } on DioException catch (error) {
      /// Parse the API exception and throw it
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
      );

      return;
    } on DioException catch (error) {
      /// Parse the API exception and throw it
      throw _parseToApiException(error);
    }
  }

  @override
  Future<(R, AuthTokenModel)> authenticate<R extends INetKitModel>({
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
        options.headers!['Authorization'] = 'Bearer $socialAccessToken';
      }

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
      final parsedModel = Converter.toModel<R>(response.data as MapType, model);

      return (parsedModel, authToken);
    } on DioException catch (error) {
      // Handle DioException errors
      throw _parseToApiException(error);
    }
  }

  @override
  Future<R?> uploadMultipartData<R extends INetKitModel>({
    required String path,

    /// The model to parse the data to
    required R model,
    required MultipartFile formData,
    required RequestMethod method,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    String? contentType,
  }) async {
    try {
      return _uploadMultipartData(
        path: path,
        model: model,
        formData: formData,
        method: method,
      );
    } on DioException catch (error) {
      throw _parseToApiException(error);
    }
  }

  void _initialize({
    required String baseUrl,
    required LogLevel logLevel,
    required bool loggerEnabled,
    required bool testMode,
    required String accessTokenKey,
    required String refreshTokenKey,
    String? refreshTokenPath,
    String? devBaseUrl,
    BaseOptions? baseOptions,
    Interceptor? interceptor,
    HttpClientAdapter? clientAdapter,
    Stream<bool>? internetStatusStream,
  }) {
    /// Initialize the logger
    _logger = NetKitLogger();

    /// Set the log level for the logger
    _logger.setLogLevel(logLevel);

    /// Initialize the converter
    _converter = const Converter();

    /// Set up the base options if not provided
    /// Making sure the BaseOptions is not null
    baseOptions ??= BaseOptions();

    parameters = NetKitParams(
      baseOptions: baseOptions,
      interceptor: interceptor,
      testMode: testMode,
      loggerEnabled: loggerEnabled,
      logLevel: logLevel,
      accessTokenKey: accessTokenKey,
      refreshTokenKey: refreshTokenKey,
      internetStatusSubscription: internetStatusStream?.listen(
        (event) {
          /// Update the internet status when the stream emits a new value
          _internetEnabled = event;
        },
      ),
    );

    /// Set up the http client adapter
    httpClientAdapter = clientAdapter ?? adapter.HttpAdapter().getAdapter();

    /// If test mode is enabled, use devBaseUrl
    parameters.testMode
        ? parameters.baseOptions.baseUrl = devBaseUrl ?? baseUrl
        : parameters.baseOptions.baseUrl = baseUrl;

    /// Set up the network manager
    options = parameters.baseOptions;

    /// Add log interceptor if logger is enabled and test mode is false
    if (parameters.loggerEnabled && testMode == false) {
      interceptors.add(LogInterceptor());
    }

    final errorInterceptor = ErrorHandlingInterceptor(
      refreshTokenPath: refreshTokenPath,
      requestQueue: RequestQueue(),
      tokenManager: TokenManager(
        addBearerToken: setAccessToken,
        addRefreshToken: setRefreshToken,
        refreshTokenRequest: _refreshTokenRequest,
        retryRequest: _retryRequest,
        onTokensUpdated: _onTokensUpdated,
        logger: _logger,
      ),
    ).getErrorInterceptor();

    interceptors.add(errorInterceptor);
  }

  /// Method to extract access and refresh tokens from headers or body.
  /// Returns an AuthTokenModel containing both tokens.
  AuthTokenModel extractTokens({
    required Response<dynamic> response,
    required String accessTokenKey,
    required String refreshTokenKey,
  }) {
    // Try to extract tokens from headers
    final accessToken = response.headers.value(accessTokenKey);
    final refreshToken = response.headers.value(refreshTokenKey);
    return AuthTokenModel(accessToken: accessToken, refreshToken: refreshToken);
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
  void setAccessToken(String? token) {
    if (token == null) return;
    baseOptions.headers.addAll({parameters.accessTokenKey: 'Bearer $token'});
  }

  @override
  void setRefreshToken(String? token) {
    if (token == null) return;
    baseOptions.headers.addAll({parameters.refreshTokenKey: token});
  }

  @override
  void removeAccessToken() {
    baseOptions.headers.remove(parameters.accessTokenKey);
  }

  @override
  void removeRefreshToken() {
    baseOptions.headers.remove(parameters.refreshTokenKey);
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

  /// Method to get the access token from the headers.
  String getRefreshToken() {
    final token = baseOptions.headers[parameters.refreshTokenKey];
    if (token == null) return '';
    return token is String ? token : '';
  }

  /// Method to be called when the tokens are updated.
  /// Calls the onTokenRefreshed callback if provided.
  /// The callback function is optional and can be set w
  /// hen initializing the network manager.
  void _onTokensUpdated(AuthTokenModel authToken) {
    // Call the callback if provided
    if (onTokenRefreshed != null) {
      onTokenRefreshed!.call(authToken);
    }
  }

  Future<AuthTokenModel> _refreshTokenRequest(String refreshTokenPath) async {
    // Remove the access token before refreshing
    removeAccessToken();

    final refreshResponse = await request<dynamic>(
      refreshTokenPath,
      options: Options(
        method: RequestMethod.post.name.toUpperCase(),
        headers: {
          parameters.refreshTokenKey: getRefreshToken(),
        },
      ),
    );
    return extractTokens(
      response: refreshResponse,
      accessTokenKey: parameters.accessTokenKey,
      refreshTokenKey: parameters.refreshTokenKey,
    );
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions requestOptions) async {
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
