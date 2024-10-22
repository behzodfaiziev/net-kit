part of '../net_kit_manager.dart';
/// Mixin for request manager
mixin RequestManagerMixin on DioMixin {
  /// Overridden parameters getter
  NetKitParams get parameters;

  /// Overridden errorParams getter
  NetKitErrorParams get errorParams;

  /// Overridden internetEnabled getter
  bool get internetEnabled;

  Future<Response<dynamic>> _sendRequest({
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
      if (!internetEnabled) {
        throw ApiException(
          message: errorParams.noInternetError,
          statusCode: HttpStatuses.serviceUnavailable.code,
        );
      }

      options ??= Options();

      /// Set the request method
      options.method = method.name.toUpperCase();

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
    } catch (error) {
      throw ApiException(
        message: error.toString(),
        statusCode: HttpStatuses.expectationFailed.code,
      );
    }
  }

  /// Check if the request failed
  /// If the status code is null or not in the range of 200-299, return true
  /// Otherwise, return false
  bool _isRequestFailed(int? statusCode) {
    /// If the status code is null, return true (request failed)
    if (statusCode == null) return true;

    /// If the status code is not in the range of 200-299,
    /// return true (request failed)
    return statusCode < HttpStatuses.ok.code ||
        statusCode >= HttpStatuses.multipleChoices.code;
  }
}
