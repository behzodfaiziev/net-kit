import '../../enum/http_status_codes.dart';
import '../../utility/typedef/request_type_def.dart';

/// The error model class
/// It contains the status code and message of the error
/// It is used to parse the error response from the server
/// and display the error message to the user
class ErrorModel {
  /// The constructor for the ErrorModel class
  const ErrorModel({
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
  factory ErrorModel.fromJson({
    required MapType? json,
    required String statusCodeKey,
    required String messageKey,
    int? statusCode,
  }) {
    try {
      String? singleMessage;
      List<String>? multipleMessages;

      if (json == null) {
        throw Exception('JSON is null');
      }

      /// Check if the message is a string or a list
      if (json[messageKey] is String) {
        singleMessage = json[messageKey] as String?;
      }

      /// If the message is a list, cast it to a list of strings
      else if (json[messageKey] is List) {
        multipleMessages = json[messageKey] as List<String>;

        if (multipleMessages.isNotEmpty) {
          /// If the list is not empty, get the first message
          singleMessage = multipleMessages[0];
        }
      }
      final status = statusCode ?? json[statusCodeKey] as int?;

      return ErrorModel(
        statusCode: status ?? HttpStatuses.badRequest.code,
        message: (singleMessage ?? '').isNotEmpty
            ? singleMessage
            : 'Could not parse the error',
        messages: multipleMessages,
      );
    } catch (e) {
      return ErrorModel(
        statusCode: HttpStatuses.badRequest.code,
        message: 'Could not parse the error',
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
