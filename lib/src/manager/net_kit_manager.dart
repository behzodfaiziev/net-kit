import 'package:dio/dio.dart';

import '../enum/http_status_codes.dart';
import '../enum/log_level.dart';
import '../enum/request_method.dart';
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

part 'error/error_handler.dart';

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
    with DioMixin
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
    );
  }

  @override
  late final NetKitParams parameters;

  late final INetKitLogger _logger;

  late final Converter _converter;

  /// This boolean value is used to determine if the internet is enabled
  /// The default value is true, meaning that
  /// the internet is enabled by default.
  /// The value is updated based on the internet status stream.
  bool _internetEnabled = true;

  @override
  BaseOptions get baseOptions => parameters.baseOptions;

  @override
  Future<R> requestModel<R extends INetKitModel<R>>({
    required String path,
    required RequestMethod method,
    required R model,
    dynamic body,
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
      final parsedModel = Converter.toModel(response.data as MapType, model);

      return parsedModel;
    } on DioException catch (error) {
      /// Parse the API exception and throw it
      throw _parseToApiException(error);
    }
  }

  @override
  Future<List<R>> requestList<R extends INetKitModel<R>>({
    required String path,
    required RequestMethod method,
    required R model,
    dynamic body,
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
        loggerEnabled: parameters.isNetKitLoggerEnabled,
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
    dynamic body,
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

  Future<Response<dynamic>> _sendRequest({
    required String path,
    required RequestMethod method,
    dynamic body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      if (!_internetEnabled) {
        throw ApiException(
          message: errorParams.noInternetError,
          statusCode: HttpStatuses.serviceUnavailable.code,
        );
      }

      options ??= Options();

      /// Set the request method
      options.method = method.name.toUpperCase();

      /// It is awaited
      final data = await _converter.toRequestBody(
        data: body,
        loggerEnabled: parameters.isNetKitLoggerEnabled,
      );

      final response = await request<dynamic>(
        path,
        data: data,
        options: options,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );

      if (isRequestFailed(response.statusCode)) {
        /// Throw an exception if the request failed
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
    }
  }

  /// Check if the request failed
  /// If the status code is null or not in the range of 200-299, return true
  /// Otherwise, return false
  bool isRequestFailed(int? statusCode) {
    /// If the status code is null, return true (request failed)
    if (statusCode == null) return true;

    /// If the status code is not in the range of 200-299,
    /// return true (request failed)
    return statusCode < HttpStatuses.ok.code ||
        statusCode >= HttpStatuses.multipleChoices.code;
  }

  void _initialize({
    required String baseUrl,
    required LogLevel logLevel,
    required bool loggerEnabled,
    required bool testMode,
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
    _converter = Converter(logger: _logger);

    /// Set up the base options if not provided
    /// Making sure the BaseOptions is not null
    baseOptions ??= BaseOptions();

    parameters = NetKitParams(
      baseOptions: baseOptions,
      interceptor: interceptor,
      testMode: testMode,
      loggerEnabled: loggerEnabled,
      logLevel: logLevel,
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
  void addBearerToken(String token) {
    baseOptions.headers.addAll({'Authorization': 'Bearer $token'});
  }

  @override
  void removeBearerToken() {
    baseOptions.headers.remove('Authorization');
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
}
