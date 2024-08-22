import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/error/api_exception.dart';
import 'package:test/test.dart';

import 'models/random_users_response_model.dart';

void main() {
  group('Random User Integration Test', () {
    late INetKitManager netKitManager;

    setUp(() {
      netKitManager = NetKitManager(
        baseUrl: 'https://randomuser.me',
        errorStatusCodeKey: 'status',
        errorMessageKey: 'description',
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
  });
}
