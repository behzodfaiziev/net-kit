import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

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
    late DioAdapter adapter;

    setUp(() {
      manager = NetKitManager(
        baseUrl: 'https://example.com',
        dataKey: 'data',
      );
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;
    });

    tearDown(() {
      manager.dispose();
      adapter.close();
    });

    test('requestModel uses response body directly when useDataKey is false',
        () async {
      adapter.onGet(
        '/model',
        (server) => server.reply(200, {'id': 42}),
      );

      final result = await manager.requestModel<_IdModel>(
        path: '/model',
        method: RequestMethod.get,
        model: const _IdModel(),
        useDataKey: false,
      );

      expect(result.id, 42);
    });

    test('requestList uses top-level list when useDataKey is false', () async {
      adapter.onGet(
        '/list',
        (server) => server.reply(
          200,
          [
            {'id': 1},
            {'id': 2},
          ],
        ),
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
  });
}
