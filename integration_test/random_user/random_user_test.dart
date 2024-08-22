import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

import 'models/random_users_response_model.dart';

void main() {
  group('Random User Integration Test', () {
    late INetKitManager netKitManager;

    setUp(() {
      netKitManager = NetKitManager(
        baseUrl: 'https://randomuser.me/',
        loggerEnabled: true,
        errorStatusCodeKey: 'status',
        errorMessageKey: 'description',
      );
    });

    test('Request a Single Model - Success Case', () async {
      final response =
          await netKitManager.requestModel<RandomUsersResponseModel>(
        path: 'api',
        method: RequestMethod.get,
        model: RandomUsersResponseModel(),
      );

      response.fold(
        (error) => fail('Request failed with error: ${error.message}'),
        (book) => expect(book, isA<RandomUsersResponseModel>()),
      );
    });

    test('Request a Single Model - Failure Case: Wrong API', () async {
      final response =
          await netKitManager.requestModel<RandomUsersResponseModel>(
        path: 'wrong-api',
        method: RequestMethod.get,
        model: RandomUsersResponseModel(),
      );

      response.fold(
        (error) {
          expect(error.message, isA<String>());
          expect(error.statusCode, isA<int>());
          expect(error.statusCode, 404);
          expect(error.message, 'Not Found');
        },
        (book) => expect(book, isA<RandomUsersResponseModel>()),
      );
    });
  });
}
