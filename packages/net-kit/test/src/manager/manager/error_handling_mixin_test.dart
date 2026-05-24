import 'dart:async';

import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/enum/http_status_codes.dart';
import 'package:test/test.dart';

class _TestModel extends INetKitModel {
  const _TestModel();

  @override
  _TestModel fromJson(Map<String, dynamic> json) => const _TestModel();

  @override
  Map<String, dynamic>? toJson() => {};
}

void main() {
  group('Error handling through requestModel', () {
    late StreamController<bool> internetStatusController;
    late NetKitManager manager;

    setUp(() {
      internetStatusController = StreamController<bool>.broadcast();
      manager = NetKitManager(
        baseUrl: 'https://example.com',
        internetStatusStream: internetStatusController.stream,
      );
    });

    tearDown(() {
      internetStatusController.close();
      manager.dispose();
    });

    test('preserves ApiException message when request is offline', () async {
      internetStatusController.add(false);
      await Future<void>.delayed(Duration.zero);

      try {
        await manager.requestModel(
          path: '/offline',
          method: RequestMethod.get,
          model: const _TestModel(),
        );
        fail('Expected ApiException');
      } on ApiException catch (e) {
        expect(e.message, 'No internet connection');
        expect(e.statusCode, HttpStatuses.serviceUnavailable.code);
      }
    });
  });
}
