import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/enum/http_status_codes.dart';
import 'package:test/test.dart';

import 'models/random_users_response_model.dart';
import 'models/wrong_random_users_response_model.dart';

void main() {
  group('Random User Integration Test', () {
    late INetKitManager netKitManager;

    setUp(() {
      netKitManager = NetKitManager(
        baseUrl: 'https://randomuser.me',
      );
    });

    test('Request a Single Model - Success Case', () async {
      try {
        final response =
            await netKitManager.requestModel<RandomUsersResponseModel>(
          path: '/api',
          method: RequestMethod.get,
          model: const RandomUsersResponseModel(),
        );
        expect(response, isA<RandomUsersResponseModel>());
      } on ApiException catch (e) {
        fail('Request failed with error: ${e.message}');
      }
    });
    test('Request a Single Model - Failure Case: Wrong API', () async {
      try {
        final response =
            await netKitManager.requestModel<RandomUsersResponseModel>(
          path: '/wrong-api',
          method: RequestMethod.get,
          model: const RandomUsersResponseModel(),
        );

        fail('Request should have failed: $response');
      } on ApiException catch (error) {
        expect(error.message, isA<String>());
        expect(error.statusCode, isA<int>());
        expect(error.statusCode, 404);
        expect(error.message, 'Not Found');
      }
    });

    test('Request a Single Model - Failure Case: Wrong Method', () async {
      try {
        final response =
            await netKitManager.requestList<RandomUsersResponseModel>(
          path: '/api',
          method: RequestMethod.get,
          model: const RandomUsersResponseModel(),
        );

        fail('Request should have failed: $response');
      } on ApiException catch (error) {
        expect(error.message, isA<String>());
        expect(error.statusCode, isA<int>());
        expect(error.statusCode, HttpStatuses.expectationFailed.code);
        expect(error.message, 'The data is not a list');
      }
    });

    test('Request a Single Model - Failure Case: Wrong UserModel type',
        () async {
      try {
        final response =
            await netKitManager.requestModel<WrongRandomUsersResponseModel>(
          path: '/api',
          method: RequestMethod.get,
          model: const WrongRandomUsersResponseModel(),
        );
        fail('Request should have failed: $response');
      } on ApiException catch (e) {
        expect(e.message, isA<String>());
        expect(e.message, 'Could not parse the response');
        expect(e.debugMessage, isA<String>());
        expect(
          e.debugMessage,
          'Could not parse the response: WrongRandomUsersResponseModel',
        );
        expect(e.statusCode, isA<int>());
        expect(e.statusCode, HttpStatuses.expectationFailed.code);
      }
    });
  });
}
