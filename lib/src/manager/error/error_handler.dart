part of '../net_kit_manager.dart';

///The ErrorHandler class is responsible for handling errors
///in network requests. It provides methods to handle different
///types of errors and to generate appropriate error responses.
class ErrorHandler {
  /// The constructor for the ErrorHandler class
  /// It takes two parameters:
  /// - errorMessageKey: The key to use for error messages
  /// - errorStatusCodeKey: The key to use for error status codes
  ErrorHandler({this.errorParams = const NetKitErrorParams()});

  /// Parameters for error messages and error keys
  final NetKitErrorParams errorParams;

  /// Returns an [ApiException] object from a DioException
  ApiException _parseToApiException(DioException exception) {
    return ApiException.fromJson(
      json: exception.response?.data ?? exception.error,
      statusCode: exception.response?.statusCode,
      params: errorParams,
    );
  }

  DioException _notMapTypeError(Response<dynamic> response) {
    return DioException(
      requestOptions: response.requestOptions,
      response: Response(
        requestOptions: response.requestOptions,
        data: {
          errorParams.messageKey: errorParams.notMapTypeError,
          errorParams.statusCodeKey: HttpStatuses.expectationFailed.code,
        },
      ),
    );
  }
}
