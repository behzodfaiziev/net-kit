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
    late StreamController<bool> internetStatusController;

    setUp(() {
      internetStatusController = StreamController<bool>();
      netKitManager = NetKitManager(
        baseUrl: 'https://<TEST-API>.com',
        internetStatusStream: internetStatusController.stream,
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
      } catch (e) {
        expect(e, isA<ApiException>());
        final apiException = e as ApiException;
        expect(apiException.message, 'No internet connection');
        expect(apiException.statusCode, HttpStatuses.serviceUnavailable.code);
      }
    });

    group('Extract tokens from headers', () {
      test(
          'should extract tokens when both access and '
          'refresh tokens are present', () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers.fromMap({
            'Authorization': ['access-token-value'],
            'Refresh-Token': ['refresh-token-value'],
          }),
        );

        final tokens = netKitManager.extractTokens(
          response: response,
          accessTokenKey: 'Authorization',
          refreshTokenKey: 'Refresh-Token',
        );

        expect(tokens.accessToken, 'access-token-value');
        expect(tokens.refreshToken, 'refresh-token-value');
      });

      test('should return null tokens when headers are missing', () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers(),
        );

        final tokens = netKitManager.extractTokens(
          response: response,
          accessTokenKey: 'Authorization',
          refreshTokenKey: 'Refresh-Token',
        );

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test('should return null access token when only refresh token is present',
          () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers.fromMap({
            'Refresh-Token': ['refresh-token-value'],
          }),
        );

        final tokens = netKitManager.extractTokens(
          response: response,
          accessTokenKey: 'Authorization',
          refreshTokenKey: 'Refresh-Token',
        );

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, 'refresh-token-value');
      });

      test('should return null refresh token when only access token is present',
          () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers.fromMap({
            'Authorization': ['access-token-value'],
          }),
        );

        final tokens = netKitManager.extractTokens(
          response: response,
          accessTokenKey: 'Authorization',
          refreshTokenKey: 'Refresh-Token',
        );

        expect(tokens.accessToken, 'access-token-value');
        expect(tokens.refreshToken, isNull);
      });

      test(
          'should extract tokens when accessTokenKey '
              'and refreshTokenKey are different',
          () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers.fromMap({
            'Access-Token': ['access-token-value'],
            'Refresh-Token': ['refresh-token-value'],
          }),
        );

        final tokens = netKitManager.extractTokens(
          response: response,
          accessTokenKey: 'Access-Token',
          refreshTokenKey: 'Refresh-Token',
        );

        expect(tokens.accessToken, 'access-token-value');
        expect(tokens.refreshToken, 'refresh-token-value');
      });

      test(
          'should return null tokens when accessTokenKey '
              'and refreshTokenKey are different and missing',
          () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers(),
        );

        final tokens = netKitManager.extractTokens(
          response: response,
          accessTokenKey: 'Access-Token',
          refreshTokenKey: 'Refresh-Token',
        );

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });

      test(
          'should extract tokens when accessTokenKey is '
          'AccessToken and refreshTokenKey is RefreshToken', () {
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers.fromMap({
            'AccessToken': ['access-token-value'],
            'RefreshToken': ['refresh-token-value'],
          }),
        );

        final tokens = netKitManager.extractTokens(
          response: response,
          accessTokenKey: 'AccessToken',
          refreshTokenKey: 'RefreshToken',
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
        );

        final tokens = netKitManager.extractTokens(
          response: response,
          accessTokenKey: 'AccessToken',
          refreshTokenKey: 'RefreshToken',
        );

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      });
    });
  });
}
