part of '../net_kit_manager.dart';

///The ErrorHandler class is responsible for handling errors
///in network requests. It provides methods to handle different
///types of errors and to generate appropriate error responses.
class ErrorHandler {
  /// The constructor for the ErrorHandler class
  /// It takes two parameters:
  /// - errorMessageKey: The key to use for error messages
  /// - errorStatusCodeKey: The key to use for error status codes
  ErrorHandler({this.params = const NetKitErrorParams()});

  /// Parameters for error messages and error keys
  final NetKitErrorParams params;

  /// Returns an [ApiException] object from a DioException
  ApiException _parseApiException(DioException error) {
    return ApiException.fromJson(
      json: error.response?.data,
      statusCode: error.response?.statusCode,
      params: params,
    );
  }

  DioException _notMapTypeError(Response<dynamic> response) {
    return DioException(
      requestOptions: response.requestOptions,
      response: Response(
        requestOptions: response.requestOptions,
        data: {
          params.messageKey: params.notMapTypeError,
          params.statusCodeKey: HttpStatuses.expectationFailed.code,
        },
      ),
    );
  }
}
