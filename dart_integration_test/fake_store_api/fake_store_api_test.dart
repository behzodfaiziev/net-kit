import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/enum/http_status_codes.dart';
import 'package:net_kit/src/error/api_exception.dart';
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
      try {
        final response = await netKitManager.requestList<TestProductModel>(
          path: '/products',
          method: RequestMethod.get,
          model: const TestProductModel(),
        );
        expect(response, isA<List<TestProductModel>>());
        expect(response, isNotEmpty);
      } on ApiException catch (e) {
        fail('Request failed with error: ${e.message}');
      }
    });

    test('Request a Single Model - Failure Case: Wrong API', () async {
      try {
        final response = await netKitManager.requestList<TestProductModel>(
          path: '/wrong-api',
          method: RequestMethod.get,
          model: const TestProductModel(),
        );

        fail('Request should have failed: $response');
      } on ApiException catch (error) {
        expect(error.message, isA<String>());
        expect(error.statusCode, isA<int>());
        expect(error.statusCode, 404);
        expect(error.message, isNotEmpty);
      }
    });

    group('Wrong method called on Manager: [netKitManager.requestModel]', () {
      test('Request a Single Model - Success Case', () async {
        try {
          final response = await netKitManager.requestModel<TestProductModel>(
            path: '/products',
            method: RequestMethod.get,
            model: const TestProductModel(),
          );

          fail('Request should have failed: $response');
        } on ApiException catch (error) {
          expect(
            error.message,
            'Could not parse the response: Not a Map type',
          );
          expect(error.statusCode, HttpStatuses.expectationFailed.code);
          expect(error.messages, isNull);
        }
      });

      test('Request a Single Model - Failure Case: Wrong API', () async {
        try {
          final response = await netKitManager.requestModel<TestProductModel>(
            path: '/wrong-api',
            method: RequestMethod.get,
            model: const TestProductModel(),
          );
          fail('Request should have failed: $response');
        } on ApiException catch (error) {
          expect(error.message, isA<String>());
          expect(error.statusCode, isA<int>());
          expect(error.statusCode, 404);
          expect(error.message, isNotEmpty);
        }
      });
    });
  });
}
