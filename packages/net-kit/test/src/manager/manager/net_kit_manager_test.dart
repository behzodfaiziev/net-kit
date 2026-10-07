import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/enum/http_status_codes.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

class MockINetKitModel extends Mock implements INetKitModel {}

void main() {
  group('NetKitManager', () {
    late NetKitManager netKitManager;
    late NetKitManager netKitManagerWithCustomDataKey;
    late NetKitManager netKitManagerWithCustomKeys;
    late NetKitManager netKitManagerWithCustomKeysAndDataKey;
    late StreamController<bool> internetStatusController;

    setUp(() {
      internetStatusController = StreamController<bool>.broadcast();
      netKitManager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: FakeTransport(),
        internetStatusStream: internetStatusController.stream,
      );

      netKitManagerWithCustomDataKey = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: FakeTransport(),
        internetStatusStream: internetStatusController.stream,
        dataKey: 'customData',
      );

      netKitManagerWithCustomKeys = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: FakeTransport(),
        internetStatusStream: internetStatusController.stream,
        accessTokenBodyKey: 'access_token',
        refreshTokenBodyKey: 'refresh_token',
        accessTokenHeaderKey: 'custom_access_token_header',
      );

      netKitManagerWithCustomKeysAndDataKey = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: FakeTransport(),
        internetStatusStream: internetStatusController.stream,
        accessTokenBodyKey: 'access_token',
        refreshTokenBodyKey: 'refresh_token',
        accessTokenHeaderKey: 'custom_access_token_header',
        dataKey: 'customData',
      );
    });

    tearDown(() {
      internetStatusController.close();
      netKitManager.dispose();
      netKitManagerWithCustomDataKey.dispose();
      netKitManagerWithCustomKeys.dispose();
      netKitManagerWithCustomKeysAndDataKey.dispose();
    });

    test(
        'throws ApiException with correct message and status '
        'code when internet connection is false', () async {
      internetStatusController.add(false);
      await Future<void>.delayed(Duration.zero);

      try {
        await netKitManager.requestModel(
          path: '/test',
          method: RequestMethod.get,
          model: MockINetKitModel(),
        );
        fail('Expected an ApiException to be thrown');
      } on Exception catch (e) {
        expect(e, isA<ApiException>());
        final apiException = e as ApiException;
        expect(apiException.message, 'No internet connection');
        expect(apiException.statusCode, HttpStatuses.serviceUnavailable.code);
        expect(apiException.type, ApiFailureType.transport);
      }
    });

    group('Extract tokens from body', () {
      test(
          'should extract tokens when both access and '
          'refresh tokens are present', () {
        final tokens = netKitManager.extractTokens(
          statusCode: 200,
          data: <String, dynamic>{
            'accessToken': 'access-token-value',
            'refreshToken': 'refresh-token-value',
          },
        );

        expect(tokens.accessToken, 'access-token-value');
        expect(tokens.refreshToken, 'refresh-token-value');
      });

      test('should return null tokens when tokens are missing', () {
        final tokens = netKitManager.extractTokens(statusCode: 200, data: null);

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should return null access token when only refresh token is present',
          () {
        final tokens = netKitManager.extractTokens(
          statusCode: 200,
          data: <String, dynamic>{'refreshToken': 'refresh-token-value'},
        );

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, 'refresh-token-value');
      });

      test('should return null refresh token when only access token is present',
          () {
        final tokens = netKitManager.extractTokens(
          statusCode: 200,
          data: <String, dynamic>{'accessToken': 'access-token-value'},
        );

        expect(tokens.accessToken, 'access-token-value');
        expect(tokens.refreshToken, isNull);
      });

      test(
          'should extract tokens when accessTokenKey '
          'and refreshTokenKey are different', () {
        final tokens = netKitManagerWithCustomKeys.extractTokens(
          statusCode: 200,
          data: <String, dynamic>{
            'access_token': 'access-token-value',
            'refresh_token': 'refresh-token-value',
          },
        );

        expect(tokens.accessToken, 'access-token-value');
        expect(tokens.refreshToken, 'refresh-token-value');
      });

      test(
          'should return null tokens when accessTokenKey is '
          'AccessToken and refreshTokenKey is RefreshToken and missing', () {
        final tokens =
            netKitManager.extractTokens(statusCode: null, data: null);

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should return null tokens when tokens are not strings', () {
        final tokens = netKitManager.extractTokens(
          statusCode: 200,
          data: <String, dynamic>{
            'accessToken': 12345, // Invalid type (int)
            'refreshToken': true, // Invalid type (bool)
          },
        );

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should return empty string tokens when values are empty', () {
        final tokens = netKitManager.extractTokens(
          statusCode: 200,
          data: <String, dynamic>{
            'accessToken': '',
            'refreshToken': '',
          },
        );

        expect(tokens.accessToken, '');
        expect(tokens.refreshToken, '');
      });

      test(
          'should return null tokens when response data is empty '
          'a map with wrong type', () {
        final tokens = netKitManager.extractTokens(
          statusCode: 200,
          data: <String, int>{},
        );

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should return null tokens when response has an error status code',
          () {
        final tokens = netKitManager.extractTokens(
          statusCode: 500,
          data: <String, dynamic>{
            'accessToken': 'access-token-value',
            'refreshToken': 'refresh-token-value',
          },
        );

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should extract tokens correctly in concurrent requests', () async {
        final data = <String, dynamic>{
          'accessToken': 'access-token-value',
          'refreshToken': 'refresh-token-value',
        };

        final results = await Future.wait([
          for (var i = 0; i < 3; i++)
            Future(
              () => netKitManager.extractTokens(statusCode: 200, data: data),
            ),
        ]);

        for (final tokens in results) {
          expect(tokens.accessToken, 'access-token-value');
          expect(tokens.refreshToken, 'refresh-token-value');
        }
      });
    });

    group("Extract tokens from body's data", () {
      test(
          'should extract tokens when both access and '
          'refresh tokens are present', () {
        final tokens = netKitManagerWithCustomDataKey.extractTokens(
          statusCode: 200,
          data: <String, dynamic>{
            'customData': {
              'accessToken': 'access-token-value',
              'refreshToken': 'refresh-token-value',
            },
          },
        );

        expect(tokens.accessToken, 'access-token-value');
        expect(tokens.refreshToken, 'refresh-token-value');
      });

      test('should return null tokens when tokens are missing', () {
        final tokens = netKitManagerWithCustomDataKey.extractTokens(
          statusCode: 200,
          data: null,
        );

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test(
          'should return null access token when only '
          'refresh token is present', () {
        final tokens = netKitManagerWithCustomDataKey.extractTokens(
          statusCode: 200,
          data: <String, dynamic>{
            'customData': {'refreshToken': 'refresh-token-value'},
          },
        );

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, 'refresh-token-value');
      });

      test(
          'should return null refresh token '
          'when only access token is present', () {
        final tokens = netKitManagerWithCustomDataKey.extractTokens(
          statusCode: 200,
          data: <String, dynamic>{
            'customData': {'accessToken': 'access-token-value'},
          },
        );

        expect(tokens.accessToken, 'access-token-value');
        expect(tokens.refreshToken, isNull);
      });

      test(
          'should extract tokens when accessTokenKey '
          'and refreshTokenKey are different', () {
        final tokens = netKitManagerWithCustomKeysAndDataKey.extractTokens(
          statusCode: 200,
          data: <String, dynamic>{
            'customData': {
              'access_token': 'access-token-value',
              'refresh_token': 'refresh-token-value',
            },
          },
        );

        expect(tokens.accessToken, 'access-token-value');
        expect(tokens.refreshToken, 'refresh-token-value');
      });

      test(
          'should return null tokens when accessTokenKey is '
          'AccessToken and refreshTokenKey is RefreshToken and missing', () {
        final tokens = netKitManagerWithCustomKeysAndDataKey.extractTokens(
          statusCode: 200,
          data: <String, dynamic>{
            'customData': {'accessToken': null, 'refreshToken': null},
          },
        );

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should return null tokens when tokens are not strings', () {
        final tokens = netKitManagerWithCustomDataKey.extractTokens(
          statusCode: 200,
          data: {
            'customData': <String, dynamic>{
              'accessToken': 12345, // Invalid type (int)
              'refreshToken': true, // Invalid type (bool)
            },
          },
        );

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should return empty string tokens when values are empty', () {
        final tokens = netKitManagerWithCustomDataKey.extractTokens(
          statusCode: 200,
          data: <String, dynamic>{
            'customData': {'accessToken': '', 'refreshToken': ''},
          },
        );

        expect(tokens.accessToken, '');
        expect(tokens.refreshToken, '');
      });

      test(
          'should return null tokens when response data is empty '
          'a map with wrong type', () {
        final tokens = netKitManagerWithCustomDataKey.extractTokens(
          statusCode: 200,
          data: {'customData': <String, int>{}},
        );

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should return null tokens when response has an error status code',
          () {
        final tokens = netKitManagerWithCustomDataKey.extractTokens(
          statusCode: 500,
          data: {
            'customData': <String, dynamic>{
              'accessToken': 'access-token-value',
              'refreshToken': 'refresh-token-value',
            },
          },
        );

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should extract tokens correctly in concurrent requests', () async {
        final data = {
          'customData': <String, dynamic>{
            'accessToken': 'access-token-value',
            'refreshToken': 'refresh-token-value',
          },
        };

        final results = await Future.wait([
          for (var i = 0; i < 3; i++)
            Future(
              () => netKitManagerWithCustomDataKey.extractTokens(
                statusCode: 200,
                data: data,
              ),
            ),
        ]);

        for (final tokens in results) {
          expect(tokens.accessToken, 'access-token-value');
          expect(tokens.refreshToken, 'refresh-token-value');
        }
      });
    });
  });

  group('setAccessToken prefix handling', () {
    late NetKitManager manager;

    setUp(() {
      manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: FakeTransport(),
      );
    });

    tearDown(() {
      manager.dispose();
    });

    test('adds Bearer prefix when token has no prefix', () {
      manager.setAccessToken('abc');
      expect(manager.getAllHeaders()['Authorization'], 'Bearer abc');
    });

    test('does not double-prefix when token already includes Bearer', () {
      manager.setAccessToken('Bearer abc');
      expect(manager.getAllHeaders()['Authorization'], 'Bearer abc');
    });

    test('uses custom accessTokenPrefix', () {
      manager.dispose();
      manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: FakeTransport(),
        accessTokenPrefix: 'Token',
      )..setAccessToken('abc');
      expect(manager.getAllHeaders()['Authorization'], 'Token abc');
    });

    test('does not double-prefix with custom accessTokenPrefix', () {
      manager.dispose();
      manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: FakeTransport(),
        accessTokenPrefix: 'Token',
      )..setAccessToken('Token abc');
      expect(manager.getAllHeaders()['Authorization'], 'Token abc');
    });

    test('prepends default prefix when token uses a different scheme', () {
      manager.setAccessToken('Basic abc');
      expect(manager.getAllHeaders()['Authorization'], 'Bearer Basic abc');
    });

    test('replaces prior token when setAccessToken is called again', () {
      manager
        ..setAccessToken('first-token')
        ..setAccessToken('second-token');
      expect(manager.getAllHeaders()['Authorization'], 'Bearer second-token');
    });
  });
}
