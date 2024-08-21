part of '../net_kit_manager.dart';

///The ErrorHandler class is responsible for handling errors
///in network requests. It provides methods to handle different
///types of errors and to generate appropriate error responses.
class ErrorHandler {
  /// The constructor for the ErrorHandler class
  /// It takes two parameters:
  /// - errorMessageKey: The key to use for error messages
  /// - errorStatusCodeKey: The key to use for error status codes
  ErrorHandler({
    required this.errorMessageKey,
    required this.errorStatusCodeKey,
  });

  /// The key to use for error messages
  /// The default value is ['message']
  final String errorMessageKey;

  /// The key to use for error status codes
  /// The default value is ['statusCode']
  final String errorStatusCodeKey;


  Left<ErrorModel, T> _errorHandler<T>(DioException error) {
    return Left(
      ErrorModel.fromJson(
        json: error.response?.data as MapType?,
        statusCode: error.response?.statusCode,
        messageKey: errorMessageKey,
        statusCodeKey: errorStatusCodeKey,
      ),
    );
  }

  DioException _notMapTypeError(Response<dynamic> response) {
    return DioException(
      requestOptions: response.requestOptions,
      response: Response(
        requestOptions: response.requestOptions,
        data: {
          errorMessageKey: 'Could not parse the response.',
          errorStatusCodeKey: 417,
        },
      ),
    );
  }
}
