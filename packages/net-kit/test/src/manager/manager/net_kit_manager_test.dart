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
    late NetKitManager netKitManagerWithCustomKeys;
    late StreamController<bool> internetStatusController;

    setUp(() {
      internetStatusController = StreamController<bool>.broadcast();
      netKitManager = NetKitManager(
        baseUrl: 'https://<TEST-API>.com',
        internetStatusStream: internetStatusController.stream,
      );

      netKitManagerWithCustomKeys = NetKitManager(
        baseUrl: 'https://<TEST-API>.com',
        internetStatusStream: internetStatusController.stream,
        accessTokenBodyKey: 'access_token',
        refreshTokenBodyKey: 'refresh_token',
        accessTokenHeaderKey: 'custom_access_token_header',
        refreshTokenHeaderKey: 'custom_refresh_token_header',
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
        final response =
            Response<dynamic>(requestOptions: RequestOptions(path: '/test'));

        final tokens = netKitManager.extractTokens(response: response);

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should return null access token when only refresh token is present',
          () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          data: <String, dynamic>{'refreshToken': 'refresh-token-value'},
        );

        final tokens = netKitManager.extractTokens(response: response);

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, 'refresh-token-value');
      });

      test('should return null refresh token when only access token is present',
          () {
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

        final tokens =
            netKitManagerWithCustomKeys.extractTokens(response: response);

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
    });
  });
}
