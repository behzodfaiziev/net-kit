import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

class _CaptureInterceptor extends Interceptor {
  final captured = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    captured.add(options);
    handler.next(options);
  }
}

class _TestModel extends INetKitModel {
  const _TestModel();

  @override
  _TestModel fromJson(Map<String, dynamic> json) => const _TestModel();

  @override
  Map<String, dynamic>? toJson() => {};
}

void main() {
  group('containsAccessToken header handling', () {
    late NetKitManager manager;
    late DioAdapter adapter;
    late _CaptureInterceptor captureInterceptor;

    setUp(() {
      captureInterceptor = _CaptureInterceptor();
      manager = NetKitManager(
        baseUrl: 'https://example.com',
        interceptor: captureInterceptor,
      )..setAccessToken('secret-token');
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;
    });

    tearDown(() {
      manager.dispose();
      adapter.close();
    });

    test(
      'does not mutate baseOptions.headers for tokenless requests',
      () async {
        adapter
          ..onGet(
            '/public',
            (server) => server.reply(200, <String, dynamic>{}),
          )
          ..onGet(
            '/private',
            (server) => server.reply(200, <String, dynamic>{}),
          );

        await Future.wait([
          manager.requestModel(
            path: '/public',
            method: RequestMethod.get,
            model: const _TestModel(),
            containsAccessToken: false,
            useDataKey: false,
          ),
          manager.requestModel(
            path: '/private',
            method: RequestMethod.get,
            model: const _TestModel(),
            useDataKey: false,
          ),
        ]);

        expect(
          manager.getAllHeaders()['Authorization'],
          'Bearer secret-token',
        );

        final publicRequest = captureInterceptor.captured.firstWhere(
          (options) => options.path == '/public',
        );
        final privateRequest = captureInterceptor.captured.firstWhere(
          (options) => options.path == '/private',
        );

        expect(publicRequest.headers['Authorization'], isNull);
        expect(privateRequest.headers['Authorization'], 'Bearer secret-token');
      },
    );

    test('includes token when containsAccessToken is null', () async {
      adapter.onGet(
        '/default-auth',
        (server) => server.reply(200, <String, dynamic>{}),
      );
      await manager.requestModel(
        path: '/default-auth',
        method: RequestMethod.get,
        model: const _TestModel(),
        useDataKey: false,
      );

      final request = captureInterceptor.captured.last;
      expect(request.headers['Authorization'], 'Bearer secret-token');
    });

    test('includes token when containsAccessToken is true', () async {
      adapter.onGet(
        '/explicit-auth',
        (server) => server.reply(200, <String, dynamic>{}),
      );
      await manager.requestModel(
        path: '/explicit-auth',
        method: RequestMethod.get,
        model: const _TestModel(),
        containsAccessToken: true,
        useDataKey: false,
      );

      final request = captureInterceptor.captured.last;
      expect(request.headers['Authorization'], 'Bearer secret-token');
    });

    test('omits custom access token header key when disabled', () async {
      manager.dispose();
      captureInterceptor = _CaptureInterceptor();
      manager = NetKitManager(
        baseUrl: 'https://example.com',
        accessTokenHeaderKey: 'X-Auth-Token',
        interceptor: captureInterceptor,
      )..setAccessToken('secret-token');
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;

      adapter.onGet(
        '/custom',
        (server) => server.reply(200, <String, dynamic>{}),
      );

      await manager.requestModel(
        path: '/custom',
        method: RequestMethod.get,
        model: const _TestModel(),
        containsAccessToken: false,
        useDataKey: false,
      );

      final request = captureInterceptor.captured.last;
      expect(request.headers['X-Auth-Token'], isNull);
      expect(request.headers['Authorization'], isNull);
    });

    test('preserves caller headers while omitting auth token', () async {
      adapter.onGet(
        '/custom-header',
        (server) => server.reply(200, <String, dynamic>{}),
      );

      await manager.requestModel(
        path: '/custom-header',
        method: RequestMethod.get,
        model: const _TestModel(),
        containsAccessToken: false,
        useDataKey: false,
        options: Options(headers: {'X-Custom': '1'}),
      );

      final request = captureInterceptor.captured.last;
      expect(request.headers['X-Custom'], '1');
      expect(request.headers['Authorization'], isNull);
    });

    test('omits auth token when caller passes Map<String, String> headers',
        () async {
      adapter.onGet(
        '/typed-headers',
        (server) => server.reply(200, <String, dynamic>{}),
      );

      await manager.requestModel(
        path: '/typed-headers',
        method: RequestMethod.get,
        model: const _TestModel(),
        containsAccessToken: false,
        useDataKey: false,
        options: Options(headers: <String, String>{'X-Custom': '1'}),
      );

      final request = captureInterceptor.captured.last;
      expect(request.headers['X-Custom'], '1');
      expect(request.headers['Authorization'], isNull);
    });

    test(
      'omits auth token when Map<String, String> already contains Authorization',
      () async {
        adapter.onGet(
          '/typed-auth-header',
          (server) => server.reply(200, <String, dynamic>{}),
        );

        await manager.requestModel(
          path: '/typed-auth-header',
          method: RequestMethod.get,
          model: const _TestModel(),
          containsAccessToken: false,
          useDataKey: false,
          options: Options(
            headers: <String, String>{
              'X-Custom': '1',
              'Authorization': 'Bearer caller-token',
            },
          ),
        );

        final request = captureInterceptor.captured.last;
        expect(request.headers['X-Custom'], '1');
        expect(request.headers['Authorization'], isNull);
      },
    );

    test('keeps baseOptions token across sequential tokenless requests',
        () async {
      for (var i = 0; i < 3; i++) {
        adapter.onGet(
          '/public-$i',
          (server) => server.reply(200, <String, dynamic>{}),
        );
        await manager.requestModel(
          path: '/public-$i',
          method: RequestMethod.get,
          model: const _TestModel(),
          containsAccessToken: false,
          useDataKey: false,
        );
        expect(
          manager.getAllHeaders()['Authorization'],
          'Bearer secret-token',
        );
      }
    });
  });
}
