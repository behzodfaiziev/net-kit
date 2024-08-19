import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../utility/typedef/request_type_def.dart';

class ErrorModel extends Equatable {
  const ErrorModel({
    required this.statusCode,
    required this.message,
    this.messages,
  });

  factory ErrorModel.fromJson({
    required MapType? json,
    int? statusCode,
    String statusCodeKey = 'status',
    String messageKey = 'message',
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
      final int? status = statusCode ?? json[statusCodeKey] as int?;

      return ErrorModel(
        statusCode: status ?? HttpStatus.badRequest,
        message: (singleMessage ?? '').isNotEmpty
            ? singleMessage
            : 'Could not parse the error',
        messages: multipleMessages,
      );
    } catch (e) {
      return const ErrorModel(
        statusCode: HttpStatus.badRequest,
        message: 'Could not parse the error',
      );
    }
  }

  final int? statusCode;
  final String? message;
  final List<String>? messages;

  @override
  List<Object?> get props => [statusCode, message, messages];
}
