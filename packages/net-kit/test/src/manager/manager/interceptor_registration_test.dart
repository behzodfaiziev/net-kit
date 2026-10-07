import 'dart:async';
import 'dart:convert';

import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

/// Records every hook call and optionally replaces what flows through.
class _RecordingInterceptor extends NetKitInterceptor {
  _RecordingInterceptor(this.name, this.log);

  final String name;
  final List<String> log;
  final requests = <RawHttpRequest>[];
  final errors = <(RawHttpRequest?, ApiException)>[];

  RawHttpRequest Function(RawHttpRequest request)? requestMapper;
  RawHttpResponse Function(RawHttpResponse response)? responseMapper;
  ApiException Function(ApiException error)? errorMapper;

  @override
  RawHttpRequest onRequest(RawHttpRequest request) {
    log.add('$name:request');
    requests.add(request);
    return requestMapper?.call(request) ?? request;
  }

  @override
  RawHttpResponse onResponse(RawHttpRequest request, RawHttpResponse response) {
    log.add('$name:response');
    return responseMapper?.call(response) ?? response;
  }

  @override
  ApiException onError(RawHttpRequest? request, ApiException error) {
    log.add('$name:error');
    errors.add((request, error));
    return errorMapper?.call(error) ?? error;
  }
}

class _SpyLogger implements INetKitLogger {
  bool debugCalled = false;
  final warnings = <String>[];

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
  void warning(String message) {
    warnings.add(message);
  }
}

class _ValueModel extends INetKitModel {
  const _ValueModel({this.value = 0});

  final int value;

  @override
  _ValueModel fromJson(Map<String, dynamic> json) =>
      _ValueModel(value: json['value'] as int? ?? 0);

  @override
  Map<String, dynamic>? toJson() => {'value': value};
}

void main() {
  group('Interceptor registration', () {
    late NetKitManager manager;
    late FakeTransport transport;
    late List<String> log;
    late _RecordingInterceptor first;
    late _RecordingInterceptor second;

    setUp(() {
      transport = FakeTransport();
      log = [];
      first = _RecordingInterceptor('first', log);
      second = _RecordingInterceptor('second', log);
      manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: transport,
        interceptors: [first, second],
        dataKey: 'data',
      );
    });

    tearDown(() {
      manager.dispose();
    });

    Future<_ValueModel> get() => manager.requestModel(
          path: '/test',
          method: RequestMethod.get,
          model: const _ValueModel(),
        );

    test('registers user-provided interceptors and invokes them on requests',
        () async {
      transport.onGet('/test', json: {'data': <String, dynamic>{}});

      await get();

      expect(manager.parameters.interceptors, [first, second]);
      expect(first.requests, hasLength(1));
      expect(second.requests, hasLength(1));
      expect(first.requests.single.uri.path, '/test');
    });

    test('runs onRequest and onResponse in registration order', () async {
      transport.onGet('/test', json: {'data': <String, dynamic>{}});

      await get();

      expect(log, [
        'first:request',
        'second:request',
        'first:response',
        'second:response',
      ]);
    });

    test('a replaced request reaches the transport and later interceptors',
        () async {
      transport.onGet('/test', json: {'data': <String, dynamic>{}});
      first.requestMapper = (request) => request.copyWith(
            headers: {...request.headers, 'X-Trace': 'trace-1'},
          );

      await get();

      expect(transport.lastRequest!.headers['X-Trace'], 'trace-1');
      expect(second.requests.single.headers['X-Trace'], 'trace-1');
    });

    test('onResponse may replace the response', () async {
      transport.onGet(
        '/test',
        json: {
          'data': {'value': 1},
        },
      );
      first.responseMapper = (response) => RawHttpResponse(
            statusCode: response.statusCode,
            headers: response.headers,
            bodyBytes: utf8.encode(
              jsonEncode({
                'data': {'value': 2},
              }),
            ),
          );

      final result = await get();

      expect(result.value, 2);
    });

    test('onError receives the ApiException and may replace it', () async {
      transport.onGet('/test', status: 404, json: {'message': 'missing'});
      first.errorMapper = (error) => ApiException(
            type: ApiFailureType.unknown,
            statusCode: 418,
            message: 'replaced',
            error: error,
          );

      await expectLater(
        get(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 418)
              .having((e) => e.message, 'message', 'replaced')
              .having((e) => e.type, 'type', ApiFailureType.unknown),
        ),
      );

      final (request, original) = first.errors.single;
      expect(request, isNotNull);
      expect(request!.uri.path, '/test');
      expect(original.statusCode, 404);
      expect(original.message, 'missing');
      expect(original.type, ApiFailureType.response);
      // The second interceptor sees the replacement.
      expect(second.errors.single.$2.statusCode, 418);
      // A 4xx is still a transport response, so onResponse runs before the
      // status check raises the error.
      expect(log, [
        'first:request',
        'second:request',
        'first:response',
        'second:response',
        'first:error',
        'second:error',
      ]);
    });

    test('onError gets a null request when the failure is offline', () async {
      manager.dispose();
      final internet = StreamController<bool>.broadcast();
      addTearDown(internet.close);
      manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: transport,
        interceptors: [first],
        internetStatusStream: internet.stream,
      );
      internet.add(false);
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        get(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.transport)
              .having((e) => e.statusCode, 'statusCode', 503),
        ),
      );

      final (request, error) = first.errors.single;
      expect(request, isNull);
      expect(error.message, 'No internet connection');
      expect(transport.requests, isEmpty);
      expect(first.requests, isEmpty);
    });
  });

  group('Logger flags', () {
    late FakeTransport transport;

    setUp(() {
      transport = FakeTransport()
        ..onGet('/test', json: {'data': <String, dynamic>{}});
    });

    test(
        'does not use custom logger when loggerEnabled is true '
        'but devMode is false', () async {
      final spyLogger = _SpyLogger();
      final manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: transport,
        logger: spyLogger,
        loggerEnabled: true,
        dataKey: 'data',
      );
      addTearDown(manager.dispose);

      await manager.requestModel(
        path: '/test',
        method: RequestMethod.get,
        model: const _ValueModel(),
      );

      expect(spyLogger.debugCalled, isFalse);
    });

    test('uses custom logger when loggerEnabled and devMode are both true',
        () async {
      final spyLogger = _SpyLogger();
      final manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: transport,
        logger: spyLogger,
        loggerEnabled: true,
        devMode: true,
        dataKey: 'data',
      );
      addTearDown(manager.dispose);

      await manager.requestModel(
        path: '/test',
        method: RequestMethod.get,
        model: const _ValueModel(),
      );

      expect(spyLogger.debugCalled, isTrue);
    });

    test('devMode warns when access token contains whitespace', () {
      final spyLogger = _SpyLogger();
      final manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: transport,
        logger: spyLogger,
        loggerEnabled: true,
        devMode: true,
      )..setAccessToken('token with space');
      addTearDown(manager.dispose);

      expect(
        spyLogger.warnings,
        contains('Access token contains whitespace or newlines (RFC 6750)'),
      );
    });
  });
}
