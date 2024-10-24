part of '../net_kit_manager.dart';

///This class is responsible for handling errors
///in network requests. It provides methods to handle different
///types of errors and to generate appropriate error responses.
mixin ErrorHandlingMixin on RequestManagerMixin {
  /// Returns an [ApiException] object from a DioException
  ApiException _parseToApiException(DioException exception) {
    return ApiException.fromJson(
      json: exception.response?.data ?? exception.error,
      statusCode: exception.response?.statusCode,
      params: _errorParams,
    );
  }

  DioException _notMapTypeError(Response<dynamic> response) {
    return DioException(
      requestOptions: response.requestOptions,
      response: Response<dynamic>(
        requestOptions: response.requestOptions,
        data: {
          _errorParams.messageKey: _errorParams.notMapTypeError,
          _errorParams.statusCodeKey: HttpStatuses.expectationFailed.code,
        },
      ),
    );
  }
}
