import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

class _IdModel extends INetKitModel {
  const _IdModel({this.id = 0});

  final int id;

  @override
  _IdModel fromJson(Map<String, dynamic> json) {
    return _IdModel(id: json['id'] as int? ?? 0);
  }

  @override
  Map<String, dynamic>? toJson() => {'id': id};
}

void main() {
  group('useDataKey false', () {
    late NetKitManager manager;
    late FakeTransport transport;

    setUp(() {
      transport = FakeTransport();
      manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: transport,
        dataKey: 'data',
      );
    });

    tearDown(() {
      manager.dispose();
    });

    test('requestModel uses response body directly when useDataKey is false',
        () async {
      transport.onGet('/model', json: {'id': 42});

      final result = await manager.requestModel<_IdModel>(
        path: '/model',
        method: RequestMethod.get,
        model: const _IdModel(),
        useDataKey: false,
      );

      expect(result.id, 42);
    });

    test('requestList uses top-level list when useDataKey is false', () async {
      transport.onGet(
        '/list',
        json: [
          {'id': 1},
          {'id': 2},
        ],
      );

      final result = await manager.requestList<_IdModel>(
        path: '/list',
        method: RequestMethod.get,
        model: const _IdModel(),
        useDataKey: false,
      );

      expect(result, hasLength(2));
      expect(result.map((item) => item.id), [1, 2]);
    });

    test('requestList accepts HTTP 200 with empty array body', () async {
      transport.onGet('/empty-list', json: <Map<String, dynamic>>[]);

      final result = await manager.requestList<_IdModel>(
        path: '/empty-list',
        method: RequestMethod.get,
        model: const _IdModel(),
        useDataKey: false,
      );

      expect(result, isEmpty);
    });
  });
}
