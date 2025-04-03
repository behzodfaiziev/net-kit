import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/enum/http_status_codes.dart';
import 'package:test/test.dart';

class MockStream extends Mock implements Stream<bool> {}

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
        baseUrl: 'https://<TEST-API>.com',
        internetStatusStream: internetStatusController.stream,
      );

      netKitManagerWithCustomDataKey = NetKitManager(
        baseUrl: 'https://<TEST-API>.com',
        internetStatusStream: internetStatusController.stream,
        dataKey: 'customData',
      );

      netKitManagerWithCustomKeys = NetKitManager(
        baseUrl: 'https://<TEST-API>.com',
        internetStatusStream: internetStatusController.stream,
        accessTokenBodyKey: 'access_token',
        refreshTokenBodyKey: 'refresh_token',
        accessTokenHeaderKey: 'custom_access_token_header',
      );

      netKitManagerWithCustomKeysAndDataKey = NetKitManager(
        baseUrl: 'https://<TEST-API>.com',
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
    });

    test(
        'throws ApiException with correct message and status '
        'code when internet connection is false', () async {
      /// Set the internet connection to false
      internetStatusController.add(false);

      /// Wait for the stream to be processed
      await Future<void>.delayed(Duration.zero);

      /// Verify that an ApiException is thrown
      /// with the correct message and status code
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
      }
    });

    group('Extract tokens from body', () {
      test(
          'should extract tokens when both access and '
          'refresh tokens are present', () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          data: <String, dynamic>{
            'accessToken': 'access-token-value',
            'refreshToken': 'refresh-token-value',
          },
        );

        final tokens = netKitManager.extractTokens(response: response);

        expect(tokens.accessToken, 'access-token-value');
        expect(tokens.refreshToken, 'refresh-token-value');
      });

      test('should return null tokens when tokens are missing', () {
        final response = Response<dynamic>(requestOptions: RequestOptions(path: '/test'));

        final tokens = netKitManager.extractTokens(response: response);

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should return null access token when only refresh token is present', () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          data: <String, dynamic>{'refreshToken': 'refresh-token-value'},
        );

        final tokens = netKitManager.extractTokens(response: response);

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, 'refresh-token-value');
      });

      test('should return null refresh token when only access token is present', () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          data: <String, dynamic>{'accessToken': 'access-token-value'},
        );

        final tokens = netKitManager.extractTokens(response: response);

        expect(tokens.accessToken, 'access-token-value');
        expect(tokens.refreshToken, isNull);
      });

      test(
          'should extract tokens when accessTokenKey '
          'and refreshTokenKey are different', () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          data: <String, dynamic>{
            'access_token': 'access-token-value',
            'refresh_token': 'refresh-token-value',
          },
        );

        final tokens = netKitManagerWithCustomKeys.extractTokens(response: response);

        expect(tokens.accessToken, 'access-token-value');
        expect(tokens.refreshToken, 'refresh-token-value');
      });

      test(
          'should return null tokens when accessTokenKey is '
          'AccessToken and refreshTokenKey is RefreshToken and missing', () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers(),
        );

        final tokens = netKitManager.extractTokens(response: response);

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should return null tokens when tokens are not strings', () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          data: <String, dynamic>{
            'accessToken': 12345, // Invalid type (int)
            'refreshToken': true, // Invalid type (bool)
          },
        );

        final tokens = netKitManager.extractTokens(response: response);

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should return empty string tokens when values are empty', () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          data: <String, dynamic>{
            'accessToken': '',
            'refreshToken': '',
          },
        );

        final tokens = netKitManager.extractTokens(response: response);

        expect(tokens.accessToken, '');
        expect(tokens.refreshToken, '');
      });
      test(
          'should return null tokens when response data is empty '
          'a map with wrong type', () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          data: <String, int>{}, // String instead of a map
        );

        final tokens = netKitManager.extractTokens(response: response);

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should return null tokens when response has an error status code', () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 500, // Internal server error
          data: <String, dynamic>{
            'accessToken': 'access-token-value',
            'refreshToken': 'refresh-token-value',
          },
        );

        final tokens = netKitManager.extractTokens(response: response);

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should extract tokens correctly in concurrent requests', () async {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          data: <String, dynamic>{
            'accessToken': 'access-token-value',
            'refreshToken': 'refresh-token-value',
          },
        );

        final results = await Future.wait([
          Future(() => netKitManager.extractTokens(response: response)),
          Future(() => netKitManager.extractTokens(response: response)),
          Future(() => netKitManager.extractTokens(response: response)),
        ]);

        for (final tokens in results) {
          expect(tokens.accessToken, 'access-token-value');
          expect(tokens.refreshToken, 'refresh-token-value');
        }
      });
    });

    group(
      "Extract tokens from body's data ",
      () {
        test(
            'should extract tokens when both access and '
            'refresh tokens are present', () {
          final response = Response<dynamic>(
            requestOptions: RequestOptions(path: '/test'),
            data: <String, dynamic>{
              'customData': {
                'accessToken': 'access-token-value',
                'refreshToken': 'refresh-token-value',
              },
            },
          );

          final tokens = netKitManagerWithCustomDataKey.extractTokens(response: response);

          expect(tokens.accessToken, 'access-token-value');
          expect(tokens.refreshToken, 'refresh-token-value');
        });

        test('should return null tokens when tokens are missing', () {
          final response = Response<dynamic>(requestOptions: RequestOptions(path: '/test'));

          final tokens = netKitManagerWithCustomDataKey.extractTokens(response: response);

          expect(tokens.accessToken, isNull);
          expect(tokens.refreshToken, isNull);
        });

        test(
            'should return null access token when only '
            'refresh token is present', () {
          final response = Response<dynamic>(
            requestOptions: RequestOptions(path: '/test'),
            data: <String, dynamic>{
              'customData': {
                'refreshToken': 'refresh-token-value',
              },
            },
          );

          final tokens = netKitManagerWithCustomDataKey.extractTokens(response: response);

          expect(tokens.accessToken, isNull);
          expect(tokens.refreshToken, 'refresh-token-value');
        });

        test(
            'should return null refresh token '
            'when only access token is present', () {
          final response = Response<dynamic>(
            requestOptions: RequestOptions(path: '/test'),
            data: <String, dynamic>{
              'customData': {
                'accessToken': 'access-token-value',
              },
            },
          );

          final tokens = netKitManagerWithCustomDataKey.extractTokens(response: response);

          expect(tokens.accessToken, 'access-token-value');
          expect(tokens.refreshToken, isNull);
        });

        test(
            'should extract tokens when accessTokenKey '
            'and refreshTokenKey are different', () {
          final response = Response<dynamic>(
            requestOptions: RequestOptions(path: '/test'),
            data: <String, dynamic>{
              'customData': {
                'access_token': 'access-token-value',
                'refresh_token': 'refresh-token-value',
              },
            },
          );

          final tokens = netKitManagerWithCustomKeysAndDataKey.extractTokens(
            response: response,
          );

          expect(tokens.accessToken, 'access-token-value');
          expect(tokens.refreshToken, 'refresh-token-value');
        });

        test(
            'should return null tokens when accessTokenKey is '
            'AccessToken and refreshTokenKey is RefreshToken and missing', () {
          final response = Response<dynamic>(
            requestOptions: RequestOptions(path: '/test'),
            headers: Headers(),
            data: <String, dynamic>{
              'customData': {
                'accessToken': null,
                'refreshToken': null,
              },
            },
          );

          final tokens = netKitManagerWithCustomKeysAndDataKey.extractTokens(
            response: response,
          );

          expect(tokens.accessToken, isNull);
          expect(tokens.refreshToken, isNull);
        });

        test('should return null tokens when tokens are not strings', () {
          final response = Response<dynamic>(
            requestOptions: RequestOptions(path: '/test'),
            data: {
              'customData': <String, dynamic>{
                'accessToken': 12345, // Invalid type (int)
                'refreshToken': true, // Invalid type (bool)
              },
            },
          );

          final tokens = netKitManagerWithCustomDataKey.extractTokens(response: response);

          expect(tokens.accessToken, isNull);
          expect(tokens.refreshToken, isNull);
        });

        test('should return empty string tokens when values are empty', () {
          final response = Response<dynamic>(
            requestOptions: RequestOptions(path: '/test'),
            data: <String, dynamic>{
              'customData': {
                'accessToken': '',
                'refreshToken': '',
              },
            },
          );

          final tokens = netKitManagerWithCustomDataKey.extractTokens(response: response);

          expect(tokens.accessToken, '');
          expect(tokens.refreshToken, '');
        });
        test(
            'should return null tokens when response data is empty '
            'a map with wrong type', () {
          final response = Response<dynamic>(
            requestOptions: RequestOptions(path: '/test'),
            data: {
              'customData': <String, int>{}, // String instead of a map
            },
          );

          final tokens = netKitManagerWithCustomDataKey.extractTokens(response: response);

          expect(tokens.accessToken, isNull);
          expect(tokens.refreshToken, isNull);
        });

        test('should return null tokens when response has an error status code', () {
          final response = Response<dynamic>(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 500, // Internal server error
            data: {
              'customData': <String, dynamic>{
                'accessToken': 'access-token-value',
                'refreshToken': 'refresh-token-value',
              },
            },
          );

          final tokens = netKitManagerWithCustomDataKey.extractTokens(response: response);

          expect(tokens.accessToken, isNull);
          expect(tokens.refreshToken, isNull);
        });

        test('should extract tokens correctly in concurrent requests', () async {
          final response = Response<dynamic>(
            requestOptions: RequestOptions(path: '/test'),
            data: {
              'customData': <String, dynamic>{
                'accessToken': 'access-token-value',
                'refreshToken': 'refresh-token-value',
              },
            },
          );

          final results = await Future.wait([
            Future(
              () => netKitManagerWithCustomDataKey.extractTokens(
                response: response,
              ),
            ),
            Future(
              () => netKitManagerWithCustomDataKey.extractTokens(
                response: response,
              ),
            ),
            Future(
              () => netKitManagerWithCustomDataKey.extractTokens(
                response: response,
              ),
            ),
          ]);

          for (final tokens in results) {
            expect(tokens.accessToken, 'access-token-value');
            expect(tokens.refreshToken, 'refresh-token-value');
          }
        });
      },
    );
  });
}
