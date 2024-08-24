import '../../enum/http_status_codes.dart';
import '../../utility/typedef/request_type_def.dart';
import '../params/net_kit_error_params.dart';

/// The error model class
/// It contains the status code and message of the error
/// It is used to parse the error response from the server
/// and display the error message to the user
class ApiException implements Exception {
  /// The constructor for the ErrorModel class
  const ApiException({
    required this.statusCode,
    required this.message,
    this.messages,
  });

  /// The factory method to parse the error response
  /// It takes in the following parameters:
  /// - [json]: The JSON response from the server
  /// - [statusCodeKey]: The key to use for the status code parsing
  /// - [messageKey]: The key to use for the error message parsing
  /// - [statusCode]: The status code of the error
  /// It returns an ErrorModel object
  /// If the error response cannot be parsed, it returns a default error message
  /// with a status code of 400
  factory ApiException.fromJson({
    required dynamic json,
    required NetKitErrorParams params,
    int? statusCode,
  }) {
    try {
      String? singleMessage;
      List<String>? multipleMessages;

      if (json == null) {
        throw ApiException(
          message: params.jsonNullError,
          statusCode: HttpStatuses.expectationFailed.code,
        );
      }

      /// Check if the message is a string
      /// If it is a string, return the error message
      if (json is String) {
        throw ApiException(
          statusCode: statusCode ?? HttpStatuses.badRequest.code,
          message: json.isNotEmpty ? json : params.jsonIsEmptyError,
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
        else if (json[params.messageKey] is List<String>) {
          multipleMessages = json[params.messageKey] as List<String>;

          if (multipleMessages.isNotEmpty) {
            /// If the list is not empty, get the first message
            singleMessage = multipleMessages[0];
          }
        }

        /// Get the status code

        final status = statusCode ?? json[params.statusCodeKey] as int?;

        /// Return the error model
        throw ApiException(
          statusCode: status ?? HttpStatuses.badRequest.code,
          message: (singleMessage ?? '').isNotEmpty
              ? singleMessage
              : params.couldNotParseError,
          messages: multipleMessages,
        );
      }

      /// If the message is not a string or a map, throw an exception
      throw ApiException(
        message: params.couldNotParseError,
        statusCode: HttpStatuses.expectationFailed.code,
      );
    } on ApiException catch (e) {
      return e;
    } catch (e) {
      return ApiException(
        statusCode: HttpStatuses.badRequest.code,
        message: params.couldNotParseError,
      );
    }
  }

  /// The status code of the error
  /// It is used to determine the type of error
  final int? statusCode;

  /// The error message, which can be used to show the error to the user
  final String? message;

  /// The list of error messages
  /// Sometimes, the server returns multiple error messages
  /// so it handles them as a list of strings
  final List<String>? messages;
}
