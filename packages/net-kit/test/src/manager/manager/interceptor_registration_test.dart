import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

class _FlagInterceptor extends Interceptor {
  bool wasCalled = false;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    wasCalled = true;
    handler.next(options);
  }
}

class _SpyLogger implements INetKitLogger {
  bool debugCalled = false;

  @override
  void debug(String message) {
    debugCalled = true;
  }

  @override
  void error(String? message) {}

  @override
  void fatal(String? message) {}

  @override
  void info(String message) {}

  @override
  void trace(String message) {}

  @override
  void warning(String message) {}
}

class _TestModel extends INetKitModel {
  const _TestModel();

  @override
  _TestModel fromJson(Map<String, dynamic> json) => const _TestModel();

  @override
  Map<String, dynamic>? toJson() => {};
}

void main() {
  group('Interceptor registration', () {
    late NetKitManager manager;
    late DioAdapter adapter;
    late _FlagInterceptor flagInterceptor;

    setUp(() {
      flagInterceptor = _FlagInterceptor();
      manager = NetKitManager(
        baseUrl: 'https://example.com',
        interceptor: flagInterceptor,
        dataKey: 'data',
      );
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;
    });

    tearDown(() {
      manager.dispose();
    });

    test('registers user-provided interceptor and invokes it on requests',
        () async {
      adapter.onGet(
        '/test',
        (server) => server.reply(200, {'data': <String, dynamic>{}}),
      );

      await manager.requestModel(
        path: '/test',
        method: RequestMethod.get,
        model: const _TestModel(),
      );

      expect(flagInterceptor.wasCalled, isTrue);
    });
  });

  group('Logger flags', () {
    late DioAdapter adapter;

    tearDown(() {
      adapter.close();
    });

    test(
        'does not use custom logger when loggerEnabled is true '
        'but devMode is false', () async {
      final spyLogger = _SpyLogger();
      final manager = NetKitManager(
        baseUrl: 'https://example.com',
        logger: spyLogger,
        loggerEnabled: true,
        dataKey: 'data',
      );
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;

      adapter.onGet(
        '/test',
        (server) => server.reply(200, {'data': <String, dynamic>{}}),
      );

      await manager.requestModel(
        path: '/test',
        method: RequestMethod.get,
        model: const _TestModel(),
      );

      expect(spyLogger.debugCalled, isFalse);
      manager.dispose();
    });

    test('uses custom logger when loggerEnabled and devMode are both true',
        () async {
      final spyLogger = _SpyLogger();
      final manager = NetKitManager(
        baseUrl: 'https://example.com',
        logger: spyLogger,
        loggerEnabled: true,
        devMode: true,
        dataKey: 'data',
      );
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;

      adapter.onGet(
        '/test',
        (server) => server.reply(200, {'data': <String, dynamic>{}}),
      );

      await manager.requestModel(
        path: '/test',
        method: RequestMethod.get,
        model: const _TestModel(),
      );

      expect(spyLogger.debugCalled, isTrue);
      manager.dispose();
    });

    test('deprecated testMode alias still enables custom logger', () async {
      final spyLogger = _SpyLogger();
      final manager = NetKitManager(
        baseUrl: 'https://example.com',
        logger: spyLogger,
        loggerEnabled: true,
        // Deprecated alias coverage for backward compatibility.
        // ignore: deprecated_member_use_from_same_package
        testMode: true,
        dataKey: 'data',
      );
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;

      adapter.onGet(
        '/test',
        (server) => server.reply(200, {'data': <String, dynamic>{}}),
      );

      await manager.requestModel(
        path: '/test',
        method: RequestMethod.get,
        model: const _TestModel(),
      );

      expect(spyLogger.debugCalled, isTrue);
      manager.dispose();
    });
  });
}
