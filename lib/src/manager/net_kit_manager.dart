import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../enum/request_method.dart';
import '../model/error/error_model.dart';
import '../model/i_net_kit_model.dart';
import '../utility/converters.dart';
import '../utility/typedef/request_type_def.dart';
import 'i_net_kit_manager.dart';
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
  NetKitManager({
    /// The base URL for the network requests
    required String baseUrl,

    /// The key to use for error messages
    /// The default value is ['message']
    super.errorMessageKey = 'message',

    /// The key to use for error status codes
    /// The default value is ['statusCode']
    super.errorStatusCodeKey = 'statusCode',

    /// The HTTP client adapter
    HttpClientAdapter? httpClientAdapter,

    /// The development base URL for test mode
    String? devBaseUrl,

    /// The base options for the network requests
    BaseOptions? baseOptions,

    /// The interceptor for the network requests
    Interceptor? interceptor,

    /// Whether the network manager is in test mode
    bool testMode = false,

    /// Whether the logger is enabled
    bool loggerEnabled = false,
  }) {
    /// Initialize the network manager
    _initialize(
      clientAdapter: httpClientAdapter,
      baseUrl: baseUrl,
      errorMessageKey: errorMessageKey,
      errorStatusCodeKey: errorStatusCodeKey,
      devBaseUrl: devBaseUrl,
      baseOptions: baseOptions,
      interceptor: interceptor,
      testMode: testMode,
      loggerEnabled: loggerEnabled,
    );
  }

  @override
  late final NetKitParams parameters;

  @override
  BaseOptions get baseOptions => parameters.baseOptions;

  @override
  RequestModel<R> requestModel<R extends INetKitModel<R>>({
    required String path,
    required RequestMethod method,
    required R model,
    dynamic body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
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
      );

      /// Check if the response data is a map
      /// If not, throw an exception
      if ((response.data is MapType) == false) {
        throw _notMapTypeError(response);
      }
      final parsedModel = Converters.toModel(response.data as MapType, model);

      return Right(parsedModel);
    } on DioException catch (error) {
      return _errorHandler(error);
    }
  }

  @override
  RequestList<R> requestList<R extends INetKitModel<R>>({
    required String path,
    required RequestMethod method,
    required R model,
    dynamic body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
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
      );
      return Right(Converters.toListModel(response.data, model));
    } on DioException catch (error) {
      return _errorHandler(error);
    }
  }

  @override
  RequestVoid requestVoid({
    required String path,
    required RequestMethod method,
    dynamic body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
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
      );

      return const Right(null);
    } on DioException catch (error) {
      return _errorHandler<void>(error);
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
  }) async {
    try {
      options ??= Options();

      /// Set the request method
      options.method = method.toString().toUpperCase();

      final response = await request<dynamic>(
        path,
        data: Converters.toRequestBody(body),
        options: options,
        onReceiveProgress: onReceiveProgress,
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
    }
  }

  bool isRequestFailed(int? statusCode) {
    if (statusCode == null) return true;
    return statusCode < HttpStatus.ok ||
        statusCode >= HttpStatus.multipleChoices;
  }

  void _initialize({
    required String baseUrl,
    required String errorMessageKey,
    required String errorStatusCodeKey,
    String? devBaseUrl,
    BaseOptions? baseOptions,
    Interceptor? interceptor,
    bool testMode = false,
    bool loggerEnabled = false,
    HttpClientAdapter? clientAdapter,
  }) {
    /// Set up the base options if not provided
    /// Making sure the BaseOptions is not null
    baseOptions ??= BaseOptions();

    parameters = NetKitParams(
      baseOptions: baseOptions,
      errorMessageKey: errorMessageKey,
      errorStatusCodeKey: errorStatusCodeKey,
      interceptor: interceptor,
      testMode: testMode,
      loggerEnabled: loggerEnabled,
    );

    /// Set up the http client adapter
    httpClientAdapter = clientAdapter ?? IOHttpClientAdapter();

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
  void clearAllHeader() {
    baseOptions.headers.clear();
  }

  @override
  void removeHeader(String key) {
    baseOptions.headers.remove(key);
  }
}
