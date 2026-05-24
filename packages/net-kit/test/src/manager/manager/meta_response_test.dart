import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

class _ItemModel extends INetKitModel {
  const _ItemModel({this.name = ''});

  final String name;

  @override
  _ItemModel fromJson(Map<String, dynamic> json) {
    return _ItemModel(name: json['name'] as String? ?? '');
  }

  @override
  Map<String, dynamic>? toJson() => {'name': name};
}

class _MetaModel extends INetKitModel {
  const _MetaModel({this.page = 0, this.total = 0});

  final int page;
  final int total;

  @override
  _MetaModel fromJson(Map<String, dynamic> json) {
    return _MetaModel(
      page: json['page'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
    );
  }

  @override
  Map<String, dynamic>? toJson() => {'page': page, 'total': total};
}

void main() {
  group('Meta response parsing', () {
    late NetKitManager manager;
    late DioAdapter adapter;

    setUp(() {
      manager = NetKitManager(
        baseUrl: 'https://example.com',
        dataKey: 'result',
      );
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;
    });

    tearDown(() {
      manager.dispose();
      adapter.close();
    });

    test('does not mutate the original response map', () async {
      final responseBody = <String, dynamic>{
        'data': {'name': 'item'},
        'page': 1,
      };

      adapter.onGet(
        '/meta',
        (server) => server.reply(200, Map<String, dynamic>.from(responseBody)),
      );

      await manager.requestModelMeta<_ItemModel, _MetaModel>(
        path: '/meta',
        method: RequestMethod.get,
        model: const _ItemModel(),
        metadataModel: const _MetaModel(),
        useDataKey: false,
      );

      expect(responseBody.containsKey('data'), isTrue);
      expect(responseBody['page'], 1);
    });

    test('useDataKey true unwraps outer dataKey before splitting meta',
        () async {
      adapter.onGet(
        '/meta',
        (server) => server.reply(
          200,
          {
            'result': {
              'data': {'name': 'nested'},
              'page': 2,
            },
          },
        ),
      );

      final result = await manager.requestModelMeta<_ItemModel, _MetaModel>(
        path: '/meta',
        method: RequestMethod.get,
        model: const _ItemModel(),
        metadataModel: const _MetaModel(),
      );

      expect(result.data.name, 'nested');
      expect(result.metadata.page, 2);
    });

    test('useDataKey false reads from top-level map without outer unwrap',
        () async {
      manager.dispose();
      manager = NetKitManager(
        baseUrl: 'https://example.com',
        dataKey: 'result',
        metadataDataKey: 'payload',
      );
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;

      adapter.onGet(
        '/meta',
        (server) => server.reply(
          200,
          {
            'payload': [
              {'name': 'a'},
              {'name': 'b'},
            ],
            'page': 3,
          },
        ),
      );

      final result = await manager.requestListMeta<_ItemModel, _MetaModel>(
        path: '/meta',
        method: RequestMethod.get,
        model: const _ItemModel(),
        metadataModel: const _MetaModel(),
        useDataKey: false,
      );

      expect(result.data, hasLength(2));
      expect(result.data.first.name, 'a');
      expect(result.metadata.page, 3);
    });

    test('supports dataKey different from metadataDataKey', () async {
      manager.dispose();
      manager = NetKitManager(
        baseUrl: 'https://example.com',
        dataKey: 'wrapper',
        metadataDataKey: 'items',
      );
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;

      adapter.onGet(
        '/meta',
        (server) => server.reply(
          200,
          {
            'wrapper': {
              'items': [
                {'name': 'x'},
              ],
              'total': 5,
            },
          },
        ),
      );

      final result = await manager.requestListMeta<_ItemModel, _MetaModel>(
        path: '/meta',
        method: RequestMethod.get,
        model: const _ItemModel(),
        metadataModel: const _MetaModel(),
      );

      expect(result.data.single.name, 'x');
      expect(result.metadata.total, 5);
    });

    test(
      'handles missing metadataDataKey with metadata-only response',
      () async {
      manager.dispose();
      manager = NetKitManager(baseUrl: 'https://example.com');
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;

      final responseBody = <String, dynamic>{'page': 1};

      adapter.onGet(
        '/meta',
        (server) => server.reply(200, Map<String, dynamic>.from(responseBody)),
      );

      await expectLater(
        manager.requestModelMeta<_ItemModel, _MetaModel>(
          path: '/meta',
          method: RequestMethod.get,
          model: const _ItemModel(),
          metadataModel: const _MetaModel(),
          useDataKey: false,
        ),
        throwsA(isA<TypeError>()),
      );

      expect(responseBody.containsKey('page'), isTrue);
    });

    test(
      'returns empty metadata when response contains only payload key',
      () async {
      manager.dispose();
      manager = NetKitManager(baseUrl: 'https://example.com');
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;

      adapter.onGet(
        '/meta',
        (server) => server.reply(
          200,
          {
            'data': {'name': 'solo'},
          },
        ),
      );

      final result = await manager.requestModelMeta<_ItemModel, _MetaModel>(
        path: '/meta',
        method: RequestMethod.get,
        model: const _ItemModel(),
        metadataModel: const _MetaModel(),
        useDataKey: false,
      );

      expect(result.data.name, 'solo');
      expect(result.metadata.page, 0);
      expect(result.metadata.total, 0);
    });

    test(
      'useDataKey true with null dataKey splits top-level response',
      () async {
      manager.dispose();
      manager = NetKitManager(baseUrl: 'https://example.com');
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;

      adapter.onGet(
        '/meta',
        (server) => server.reply(
          200,
          {
            'data': {'name': 'top-level'},
            'page': 4,
          },
        ),
      );

      final result = await manager.requestModelMeta<_ItemModel, _MetaModel>(
        path: '/meta',
        method: RequestMethod.get,
        model: const _ItemModel(),
        metadataModel: const _MetaModel(),
      );

      expect(result.data.name, 'top-level');
      expect(result.metadata.page, 4);
    });

    test('parsed models stay stable when nested source map is mutated',
        () async {
      final nestedResult = <String, dynamic>{
        'data': {'name': 'before'},
        'page': 9,
      };
      final responseBody = <String, dynamic>{'result': nestedResult};

      adapter.onGet(
        '/meta',
        (server) => server.reply(200, Map<String, dynamic>.from(responseBody)),
      );

      final result = await manager.requestModelMeta<_ItemModel, _MetaModel>(
        path: '/meta',
        method: RequestMethod.get,
        model: const _ItemModel(),
        metadataModel: const _MetaModel(),
      );

      nestedResult['data'] = {'name': 'mutated'};
      nestedResult['page'] = 99;

      expect(result.data.name, 'before');
      expect(result.metadata.page, 9);
    });

    test('throws when metadataDataKey payload is not a map', () async {
      manager.dispose();
      manager = NetKitManager(baseUrl: 'https://example.com');
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;

      adapter.onGet(
        '/meta',
        (server) => server.reply(
          200,
          {
            'data': 'not-a-map',
            'page': 1,
          },
        ),
      );

      await expectLater(
        manager.requestModelMeta<_ItemModel, _MetaModel>(
          path: '/meta',
          method: RequestMethod.get,
          model: const _ItemModel(),
          metadataModel: const _MetaModel(),
          useDataKey: false,
        ),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
