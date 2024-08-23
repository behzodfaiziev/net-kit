import 'package:net_kit/src/enum/http_status_codes.dart';
import 'package:net_kit/src/error/api_exception.dart';
import 'package:net_kit/src/manager/params/net_kit_error_params.dart';
import 'package:test/test.dart';

void main() {
  const errorParams = NetKitErrorParams();

  group('ApiException.fromJson', () {
    test('should create ApiException from JSON with a single message', () {
      final json = {
        'status': 500,
        'message': 'Internal Server Error',
      };
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, 500);
      expect(apiException.message, 'Internal Server Error');
      expect(apiException.messages, isNull);
    });

    test('should create ApiException from JSON with multiple messages', () {
      final json = {
        'status': 422,
        'message': ['Validation failed', 'Email is required'],
      };
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, 422);
      expect(apiException.message, 'Validation failed');
      expect(apiException.messages, ['Validation failed', 'Email is required']);
    });

    test('should create ApiException from JSON with missing message key', () {
      final json = {
        'status': 401,
      };
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, 401);
      expect(apiException.message, 'Could not parse the error');
      expect(apiException.messages, isNull);
    });

    test('should handle JSON with wrong type for status', () {
      final json = {
        'status': '500',
        'message': 'Internal Server Error',
      };
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, 400);
      expect(apiException.message, 'Could not parse the error');
      expect(apiException.messages, isNull);
    });

    test('should handle JSON with wrong type for message', () {
      final json = {
        'status': 400,
        'message': 500,
      };
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, 400);
      expect(apiException.message, 'Could not parse the error');
      expect(apiException.messages, isNull);
    });

    test('should handle JSON with wrong type for messages', () {
      final json = {
        'status': 400,
        'message': ['Invalid Request', 123],
      };
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, 400);
      expect(apiException.message, 'Could not parse the error');
      expect(apiException.messages, isNull);
    });

    test('should handle JSON with null message key', () {
      final json = {
        'status': 400,
        'message': null,
      };
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, 400);
      expect(apiException.message, 'Could not parse the error');
      expect(apiException.messages, isNull);
    });

    test('should handle JSON with empty string message', () {
      final json = {
        'status': 400,
        'message': '',
      };
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, 400);
      expect(apiException.message, 'Could not parse the error');
      expect(apiException.messages, isNull);
    });

    test('should handle JSON with empty list message', () {
      final json = {
        'status': 400,
        'message': <String>[],
      };
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, 400);
      expect(apiException.message, 'Could not parse the error');
      expect(apiException.messages, isEmpty);
    });

    test('should handle JSON with mixed types in message list', () {
      final json = {
        'status': 400,
        'message': ['Invalid Request', 123, 'Missing parameters'],
      };
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, 400);
      expect(apiException.message, 'Could not parse the error');
      expect(apiException.messages, isNull);
    });

    test('should handle JSON with missing status key', () {
      const errorMessage = 'Error occurred';

      final json = {'message': errorMessage};
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, 400);
      expect(apiException.message, errorMessage);
      expect(apiException.messages, isNull);
    });

    test('should create ApiException from JSON when json is a string', () {
      const json = 'Internal Server Error';
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, 400);
      expect(apiException.message, 'Internal Server Error');
      expect(apiException.messages, isNull);
    });

    test('should handle JSON when json is a string but empty', () {
      const json = '';
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, 400);
      expect(apiException.message, 'Empty error message');
      expect(apiException.messages, isNull);
    });

    test('should create ApiException from JSON when json is a list of strings',
        () {
      final json = ['Error 1', 'Error 2'];
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, HttpStatuses.expectationFailed.code);
      expect(apiException.message, 'Could not parse the error');
      expect(apiException.messages, null);
    });

    test('should handle JSON when json is an empty list', () {
      final json = <String>[];
      final apiException = ApiException.fromJson(
        json: json,
        params: errorParams,
      );
      expect(apiException.statusCode, HttpStatuses.expectationFailed.code);
      expect(apiException.message, 'Could not parse the error');
      expect(apiException.messages, null);
    });
  });

  test('should handle JSON when json null', () {
    final apiException = ApiException.fromJson(
      json: null,
      params: errorParams,
    );
    expect(apiException.statusCode, HttpStatuses.expectationFailed.code);
    expect(apiException.message, 'Empty error message');
    expect(apiException.messages, null);
  });
}
