import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../enum/request_method.dart';
import '../interface/i_net_kit_model.dart';
import '../model/error/error_model.dart';
import '../utility/converters.dart';
import '../utility/typedef/request_type_defs.dart';
import 'i_net_kit_manager.dart';
import 'params/net_kit_params.dart';

/// The NetKitManager class is a network manager that extends DioMixin and
/// implements the INetKitManager interface.
/// It is designed to handle HTTP requests and responses, providing methods to
/// send requests and parse responses into models or lists of models.
/// The class supports various configurations such as base URLs, interceptors,
/// SSL certificate bypassing, and logging. It also includes error handling and
/// response validation mechanisms. The NetKitManager is initialized with
/// parameters that define its behavior and can be used to perform network
/// operations in a structured and consistent manner.
class NetKitManager extends DioMixin implements INetKitManager {
  NetKitManager({
    required String baseUrl,
    required BaseOptions baseOptions,
    required Interceptor interceptor,
    String? devBaseUrl,
    bool testMode = false,
    // bool bypassSSLCertificate = false,
    bool loggerEnabled = false,
  }) {
    parameters = NetKitParams(
      baseOptions: baseOptions,
      interceptor: interceptor,
      testMode: testMode,
      // bypassSSLCertificate: bypassSSLCertificate,
      loggerEnabled: loggerEnabled,
    );

    /// Initialize the network manager
    _initialize(devBaseUrl, baseUrl, testMode);
  }

  @override
  late final NetKitParams parameters;

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
        throw DioException(
          requestOptions: response.requestOptions,
          error: 'Could not parse the response.',
        );
      }
      return Right(Converters.toModel(response.data as MapType, model));
    } on DioException catch (error) {
      return Left(
        ErrorModel(
          statusCode: error.response?.statusCode,
          description: error.response?.data.toString(),
        ),
      );
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
      return Left(
        ErrorModel(
          statusCode: error.response?.statusCode,
          description: error.response?.data.toString(),
        ),
      );
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
      return Left(
        ErrorModel(
          statusCode: error.response?.statusCode,
          description: error.response?.data.toString(),
        ),
      );
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
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
        );
      }
      return response;
    } on DioException {
      rethrow;
    } on Exception {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        error: 'Something went wrong: exception thrown',
      );
    }
  }

  bool isRequestFailed(int? statusCode) {
    if (statusCode == null) return true;
    return statusCode < HttpStatus.ok ||
        statusCode >= HttpStatus.multipleChoices;
  }

  void _initialize(String? devBaseUrl, String baseUrl, bool testMode) {
    /// Set up the http client adapter
    httpClientAdapter = IOHttpClientAdapter();

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
}
