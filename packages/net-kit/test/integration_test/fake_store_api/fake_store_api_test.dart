import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/enum/http_status_codes.dart';
import 'package:test/test.dart';

import 'model/test_product_model.dart';
import 'model/wrong_type_test_product_model.dart';

void main() {
  late INetKitManager netKitManager;
  setUp(() {
    netKitManager = NetKitManager(baseUrl: 'https://fakestoreapi.com');
  });

  group('FakeStoreApi Integration Test', () {
    test('Request List of TestProductModel - Success Case', () async {
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

    test('Request List of TestProductModel - Failure Case: Wrong API',
        () async {
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
    test('Request List of TestProductModel - Failure Case: Wrong Model',
        () async {
      try {
        final response =
            await netKitManager.requestList<WrongTypeTestProductModel>(
          path: '/products',
          method: RequestMethod.get,
          model: const WrongTypeTestProductModel(),
        );

        fail('Request should have failed: $response');
      } on ApiException catch (error) {
        expect(error.statusCode, isA<int>());
        expect(error.statusCode, 417);
        expect(error.message, isA<String>());
        expect(error.message, isNotEmpty);
        expect(error.message, 'Could not parse the response');
        expect(error.debugMessage, isNotEmpty);
        expect(
          error.debugMessage,
          'Could not parse the response: WrongTypeTestProductModel',
        );
        expect(error.error, isNotNull);
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
