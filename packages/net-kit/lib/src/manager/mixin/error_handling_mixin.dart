part of '../net_kit_manager.dart';

/// Maps transport and decoding failures to [ApiException].
mixin ErrorHandlingMixin on RequestManagerMixin {
  @override
  ApiException _fromRawException(RawHttpException exception) {
    switch (exception.type) {
      case RawHttpFailureType.timeout:
        return ApiException(
          type: ApiFailureType.timeout,
          statusCode: 408,
          message: _errorParams.timeoutError,
          error: exception,
        );
      case RawHttpFailureType.cancellation:
        return ApiException(
          type: ApiFailureType.cancelled,
          statusCode: null,
          message: _errorParams.requestCancelledError,
          error: exception,
        );
      case RawHttpFailureType.connection:
      case RawHttpFailureType.tls:
        return ApiException(
          type: ApiFailureType.transport,
          statusCode: HttpStatuses.serviceUnavailable.code,
          message: _errorParams.socketExceptionError,
          debugMessage: exception.message,
          error: exception,
        );
      case RawHttpFailureType.invalidResponse:
      case RawHttpFailureType.unknown:
        return ApiException(
          type: ApiFailureType.transport,
          statusCode: HttpStatuses.serviceUnavailable.code,
          message: _errorParams.transportError,
          debugMessage: exception.message,
          error: exception,
        );
    }
  }

  ApiException _emptyResponseBodyError(_Outcome outcome) => ApiException(
        type: ApiFailureType.decoding,
        statusCode: outcome.statusCode,
        message: _errorParams.emptyResponseBodyError,
      );

  ApiException _notMapTypeError() => ApiException(
        type: ApiFailureType.decoding,
        statusCode: HttpStatuses.expectationFailed.code,
        message: _errorParams.notMapTypeError,
      );
}
