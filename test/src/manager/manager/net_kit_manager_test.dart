import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/enum/http_status_codes.dart';
import 'package:test/test.dart';

class MockStream extends Mock implements Stream<bool> {}

class MockINetKitModel extends Mock implements INetKitModel<MockINetKitModel> {}

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
  });
}
