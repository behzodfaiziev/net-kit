import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/enum/http_status_codes.dart';
import 'package:test/test.dart';

import 'model/test_product_model.dart';

void main() {
  late INetKitManager netKitManager;
  setUp(() {
    netKitManager = NetKitManager(
      baseUrl: 'https://fakestoreapi.com',
      errorStatusCodeKey: 'status',
      errorMessageKey: 'description',
    );
  });

  group('FakeStoreApi Integration Test', () {
    test('Request a Single Model - Success Case', () async {
      final response = await netKitManager.requestList<TestProductModel>(
        path: '/products',
        method: RequestMethod.get,
        model: const TestProductModel(),
      );

      response.fold(
        (error) => fail('Request failed with error: ${error.message}'),
        (book) {
          expect(book, isA<List<TestProductModel>>());
          expect(book, isNotEmpty);
        },
      );
    });

    test('Request a Single Model - Failure Case: Wrong API', () async {
      final response = await netKitManager.requestList<TestProductModel>(
        path: '/wrong-api',
        method: RequestMethod.get,
        model: const TestProductModel(),
      );

      response.fold(
        (error) {
          expect(error.message, isA<String>());
          expect(error.statusCode, isA<int>());
          expect(error.statusCode, 404);
          expect(error.message, isNotEmpty);
        },
        (book) => expect(book, isA<TestProductModel>()),
      );
    });
  });

  group('Wrong method called on Manager: [netKitManager.requestModel]', () {
    test('Request a Single Model - Success Case', () async {
      final response = await netKitManager.requestModel<TestProductModel>(
        path: '/products',
        method: RequestMethod.get,
        model: const TestProductModel(),
      );

      response.fold(
        (error) {
          expect(error.messages, isNull);
          expect(error.message, 'Could not parse the response: Not a Map type');
          expect(error.statusCode, HttpStatuses.expectationFailed.code);
        },
        (book) {},
      );
    });

    test('Request a Single Model - Failure Case: Wrong API', () async {
      final response = await netKitManager.requestModel<TestProductModel>(
        path: '/wrong-api',
        method: RequestMethod.get,
        model: const TestProductModel(),
      );

      response.fold(
        (error) {
          expect(error.message, isA<String>());
          expect(error.statusCode, isA<int>());
          expect(error.statusCode, 404);
          expect(error.message, isNotEmpty);
        },
        (book) => expect(book, isA<TestProductModel>()),
      );
    });
  });
}
