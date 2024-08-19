import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:net_kit/src/model/error/error_model.dart';

void main() {
  group('ErrorModel.fromJson', () {
    test('should create ErrorModel from JSON with a single message', () {
      final json = {
        'status': 500,
        'message': 'Internal Server Error',
      };
      final errorModel = ErrorModel.fromJson(
        json: json,
        statusCodeKey: 'status',
        messageKey: 'message',
      );
      expect(errorModel.statusCode, 500);
      expect(errorModel.message, 'Internal Server Error');
      expect(errorModel.messages, isNull);
    });

    test('should create ErrorModel from JSON with multiple messages', () {
      final json = {
        'status': 422,
        'message': ['Validation failed', 'Email is required'],
      };
      final errorModel = ErrorModel.fromJson(
        json: json,
        statusCodeKey: 'status',
        messageKey: 'message',
      );
      expect(errorModel.statusCode, 422);
      expect(errorModel.message, 'Validation failed');
      expect(errorModel.messages, ['Validation failed', 'Email is required']);
    });

    test('should create ErrorModel from JSON with missing message key', () {
      final json = {
        'status': 401,
      };
      final errorModel = ErrorModel.fromJson(
        json: json,
        statusCodeKey: 'status',
        messageKey: 'message',
      );
      expect(errorModel.statusCode, 401);
      expect(errorModel.message, 'Could not parse the error');
      expect(errorModel.messages, isNull);
    });

    test('should handle JSON with wrong type for status', () {
      final json = {
        'status': '500',
        'message': 'Internal Server Error',
      };
      final errorModel = ErrorModel.fromJson(
        json: json,
        statusCodeKey: 'status',
        messageKey: 'message',
      );
      expect(errorModel.statusCode, HttpStatus.badRequest);
      expect(errorModel.message, 'Could not parse the error');
      expect(errorModel.messages, isNull);
    });

    test('should handle JSON with wrong type for message', () {
      final json = {
        'status': HttpStatus.badRequest,
        'message': 500,
      };
      final errorModel = ErrorModel.fromJson(
        json: json,
        statusCodeKey: 'status',
        messageKey: 'message',
      );
      expect(errorModel.statusCode, HttpStatus.badRequest);
      expect(errorModel.message, 'Could not parse the error');
      expect(errorModel.messages, isNull);
    });

    test('should handle JSON with wrong type for messages', () {
      final json = {
        'status': 400,
        'message': ['Invalid Request', 123],
      };
      final errorModel = ErrorModel.fromJson(
        json: json,
        statusCodeKey: 'status',
        messageKey: 'message',
      );
      expect(errorModel.statusCode, HttpStatus.badRequest);
      expect(errorModel.message, 'Could not parse the error');
      expect(errorModel.messages, isNull);
    });

    test('should handle JSON with null message key', () {
      final json = {
        'status': 400,
        'message': null,
      };
      final errorModel = ErrorModel.fromJson(
        json: json,
        statusCodeKey: 'status',
        messageKey: 'message',
      );
      expect(errorModel.statusCode, 400);
      expect(errorModel.message, 'Could not parse the error');
      expect(errorModel.messages, isNull);
    });

    test('should handle JSON with empty string message', () {
      final json = {
        'status': 400,
        'message': '',
      };
      final errorModel = ErrorModel.fromJson(
        json: json,
        statusCodeKey: 'status',
        messageKey: 'message',
      );
      expect(errorModel.statusCode, 400);
      expect(errorModel.message, 'Could not parse the error');
      expect(errorModel.messages, isNull);
    });

    test('should handle JSON with empty list message', () {
      final json = {
        'status': 400,
        'message': <String>[],
      };
      final errorModel = ErrorModel.fromJson(
        json: json,
        statusCodeKey: 'status',
        messageKey: 'message',
      );
      expect(errorModel.statusCode, 400);
      expect(errorModel.message, 'Could not parse the error');
      expect(errorModel.messages, isEmpty);
    });

    test('should handle JSON with mixed types in message list', () {
      final json = {
        'status': 400,
        'message': ['Invalid Request', 123, 'Missing parameters'],
      };
      final errorModel = ErrorModel.fromJson(
        json: json,
        statusCodeKey: 'status',
        messageKey: 'message',
      );
      expect(errorModel.statusCode, HttpStatus.badRequest);
      expect(errorModel.message, 'Could not parse the error');
      expect(errorModel.messages, isNull);
    });

    test('should handle JSON with missing status key', () {
      const String errorMessage = 'Error occurred';

      final json = {
        'message': errorMessage,
      };
      final errorModel = ErrorModel.fromJson(
        json: json,
        statusCodeKey: 'status',
        messageKey: 'message',
      );
      expect(errorModel.statusCode, HttpStatus.badRequest);
      expect(errorModel.message, errorMessage);
      expect(errorModel.messages, isNull);
    });
  });
}
