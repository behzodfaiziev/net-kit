import 'dart:convert';

import '../../enum/http_status_codes.dart';
import '../../utility/typedef/request_type_def.dart';
import '../params/net_kit_error_params.dart';
import 'api_failure_type.dart';

/// The error thrown by every `NetKitManager` request.
///
/// [type] says what kind of failure happened; [statusCode] and [message]
/// carry the HTTP status and the parsed server message for
/// [ApiFailureType.response] errors, or a synthetic status and a configurable
/// message (see `NetKitErrorParams`) for the other types. Transport-library
/// exceptions never escape `NetKitManager`; the original error, when any, is
/// available in [error].
class ApiException implements Exception {
  /// The constructor for the ApiException class
  const ApiException({
    required this.statusCode,
    required this.message,
    this.type = ApiFailureType.response,
    this.messages,
    this.debugMessage,
    this.error,
    this.fromRefresh = false,
  });

  /// The factory method to parse the error response
  /// It takes in the following parameters:
  /// - [json]: The JSON response from the server
  /// - [statusCode]: The status code of the error
  /// It returns an ErrorModel object
  /// If the error response cannot be parsed, it returns a default error message
  /// with a status code of 400
  factory ApiException.fromJson({
    required dynamic json,
    required NetKitErrorParams params,
    int? statusCode,
    ApiFailureType type = ApiFailureType.response,
  }) {
    try {
      String? singleMessage;
      List<String>? multipleMessages;

      if (json == null) {
        throw ApiException(
          message: params.jsonNullError,
          statusCode: statusCode ?? HttpStatuses.expectationFailed.code,
          type: type,
        );
      }

      if (json is JsonUnsupportedObjectError) {
        throw ApiException(
          statusCode: statusCode ?? HttpStatuses.badRequest.code,
          message: params.jsonUnsupportedObjectError,
          type: type,
        );
      }

      /// Check if the message is a string
      /// If it is a string, return the error message
      if (json is String) {
        throw ApiException(
          statusCode: statusCode ?? HttpStatuses.badRequest.code,
          message: json.isNotEmpty ? json : params.jsonIsEmptyError,
          type: type,
        );
      }

      /// Check if the message is a map
      /// If it is a map, parse the error message and status code
      if (json is MapType && json.isNotEmpty) {
        /// Check if the message is a string or a list
        if (json[params.messageKey] is String) {
          singleMessage = json[params.messageKey] as String?;
        }

        /// If the message is a list, cast it to a list of strings
        else if (json[params.messageKey] is List) {
          multipleMessages = (json[params.messageKey] as List)
              .map((e) => e.toString())
              .toList();

          if (multipleMessages.isNotEmpty) {
            /// If the list is not empty, get the first message
            singleMessage = multipleMessages[0];
          }
        }

        /// Get the status code

        final status = statusCode ?? json[params.statusCodeKey];

        /// Return the error model
        throw ApiException(
          statusCode:
              status is int ? status : HttpStatuses.expectationFailed.code,
          message: (singleMessage ?? '').isNotEmpty
              ? singleMessage
              : params.couldNotParseError,
          messages: multipleMessages,
          type: type,
        );
      }

      /// the runtime type of the json is a socket exception.
      /// It is used in order not to import the dart:io package
      if (json.runtimeType.toString().contains('SocketException')) {
        throw ApiException(
          statusCode: HttpStatuses.serviceUnavailable.code,
          message: params.socketExceptionError,
          type: ApiFailureType.transport,
        );
      }

      /// If the message is not a string or a map, throw an exception
      throw ApiException(
        message: params.couldNotParseError,
        statusCode: statusCode ?? HttpStatuses.expectationFailed.code,
        type: type,
      );
    } on ApiException catch (e) {
      return e;
    } on Exception {
      return ApiException(
        statusCode: statusCode ?? HttpStatuses.badRequest.code,
        message: params.couldNotParseError,
        type: type,
      );
    }
  }

  /// Failure classification.
  final ApiFailureType type;

  /// The status code of the error.
  ///
  /// The HTTP status for [ApiFailureType.response]; a synthetic status for
  /// other types (`408` for timeouts, `503` for transport failures and
  /// offline, `401` for missing or unrefreshable credentials, `400` for
  /// rejected request configuration) and `null` for cancellation.
  final int? statusCode;

  /// The error message, which can be used to show the error to the user
  final String? message;

  /// The list of error messages
  /// Sometimes, the server returns multiple error messages
  /// so it handles them as a list of strings
  final List<String>? messages;

  /// The error message, used for debugging
  final String? debugMessage;

  /// The error object, used for debugging
  final Object? error;

  /// Whether this failure happened while refreshing the access token on
  /// behalf of the request, rather than in the request itself.
  ///
  /// A refresh failure keeps its own classification in [type]: an offline
  /// device is `transport`, a slow refresh endpoint is `timeout`, a `503`
  /// from the refresh endpoint is `response` with `statusCode` 503. None of
  /// these end the session; only [ApiFailureType.sessionInvalidated] does.
  final bool fromRefresh;

  /// Returns a copy marked as a refresh failure.
  ApiException asRefreshFailure() => ApiException(
        statusCode: statusCode,
        message: message,
        type: type,
        messages: messages,
        debugMessage: debugMessage,
        error: error,
        fromRefresh: true,
      );

  @override
  String toString() => 'ApiException($type, $statusCode'
      '${fromRefresh ? ', refresh' : ''}): $message';
}
