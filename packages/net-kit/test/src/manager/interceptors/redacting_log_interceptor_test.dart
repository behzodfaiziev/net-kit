import 'dart:convert';

import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

void main() {
  late List<String> lines;
  late RedactingLogInterceptor interceptor;

  String output() => lines.join('\n');

  setUp(() {
    lines = [];
    interceptor = RedactingLogInterceptor(
      sensitiveHeaders: const ['X-Custom-Secret'],
      logPrint: (object) => lines.add(object.toString()),
    );
  });

  RawHttpRequest request({RawHttpBody? body}) => RawHttpRequest(
        uri: Uri.parse('https://api.example.com/me'),
        method: RawHttpMethod.get,
        headers: {
          'Authorization': 'Bearer test-token-value',
          'Cookie': 'sid=cookie-value',
          'X-Api-Key': 'api-key-value',
          'X-Custom-Secret': 'custom-value',
          'Accept': 'application/json',
        },
        body: body ??
            BytesRawHttpBody(
              utf8.encode(jsonEncode({'refreshToken': 'refresh-value'})),
            ),
      );

  RawHttpResponse response() => RawHttpResponse(
        statusCode: 200,
        headers: {
          'set-cookie': ['sid=new-cookie; HttpOnly', 'theme=dark'],
          'x-refresh-token': ['refresh-header-value'],
          'etag': ['"v1"'],
        },
        bodyBytes: utf8.encode(jsonEncode({'accessToken': 'new-token-value'})),
      );

  group('RedactingLogInterceptor', () {
    test('redacts sensitive request headers and keeps the others', () {
      interceptor.onRequest(request());

      expect(output(), contains('*** Request ***'));
      expect(output(), contains('uri: https://api.example.com/me'));
      expect(output(), contains('method: GET'));
      expect(output(), contains('Authorization: [REDACTED]'));
      expect(output(), contains('Cookie: [REDACTED]'));
      expect(output(), contains('X-Api-Key: [REDACTED]'));
      expect(output(), contains('X-Custom-Secret: [REDACTED]'));
      expect(output(), contains('Accept: application/json'));
      expect(output(), isNot(contains('test-token-value')));
      expect(output(), isNot(contains('cookie-value')));
      expect(output(), isNot(contains('api-key-value')));
      expect(output(), isNot(contains('custom-value')));
    });

    test('returns the request unchanged', () {
      final original = request();
      expect(interceptor.onRequest(original), same(original));
    });

    test('never prints the request body by default', () {
      interceptor.onRequest(request());

      expect(output(), isNot(contains('refresh-value')));
      expect(output(), isNot(contains('body:')));
    });

    test('never prints the response body by default', () {
      interceptor.onResponse(request(), response());

      expect(output(), isNot(contains('new-token-value')));
      expect(output(), isNot(contains('body:')));
    });

    test('redacts Set-Cookie and auth headers on responses', () {
      final original = response();
      final result = interceptor.onResponse(request(), original);

      expect(result, same(original));
      expect(output(), contains('*** Response ***'));
      expect(output(), contains('uri: https://api.example.com/me'));
      expect(output(), contains('statusCode: 200'));
      expect(output(), contains('set-cookie: [REDACTED]'));
      expect(output(), contains('x-refresh-token: [REDACTED]'));
      expect(output(), contains('etag: "v1"'));
      expect(output(), isNot(contains('new-cookie')));
      expect(output(), isNot(contains('refresh-header-value')));
    });

    test('header matching is case-insensitive', () {
      interceptor.onRequest(
        RawHttpRequest(
          uri: Uri.parse('https://api.example.com'),
          method: RawHttpMethod.get,
          headers: {'AUTHORIZATION': 'x', 'authorization': 'y'},
        ),
      );

      expect(lines.where((l) => l.contains('[REDACTED]')), hasLength(2));
      expect(
        output(),
        isNot(matches(RegExp('authorization: [xy]', caseSensitive: false))),
      );
    });

    test('logBodies prints request and response bodies', () {
      interceptor = RedactingLogInterceptor(
        logBodies: true,
        logPrint: (object) => lines.add(object.toString()),
      )
        ..onRequest(request())
        ..onResponse(request(), response());

      expect(output(), contains('body: {"refreshToken":"refresh-value"}'));
      expect(output(), contains('body: {"accessToken":"new-token-value"}'));
    });

    test('logBodies applies bodySanitizer before printing', () {
      interceptor = RedactingLogInterceptor(
        logBodies: true,
        bodySanitizer: (body) => body
            .replaceAll('refresh-value', '<masked>')
            .replaceAll('new-token-value', '<masked>'),
        logPrint: (object) => lines.add(object.toString()),
      )
        ..onRequest(request())
        ..onResponse(request(), response());

      expect(output(), contains('body: {"refreshToken":"<masked>"}'));
      expect(output(), contains('body: {"accessToken":"<masked>"}'));
      expect(output(), isNot(contains('refresh-value')));
      expect(output(), isNot(contains('new-token-value')));
    });

    test('logBodies describes streamed and multipart bodies without content',
        () {
      interceptor = RedactingLogInterceptor(
        logBodies: true,
        logPrint: (object) => lines.add(object.toString()),
      )
        ..onRequest(
          request(
            body: StreamRawHttpBody(
              stream: Stream.value(utf8.encode('secret-stream')),
              contentLength: 13,
            ),
          ),
        )
        ..onRequest(
          request(
            body: const NetKitFormData(
              fields: [MapEntry('token', 'secret-field')],
            ),
          ),
        );

      expect(output(), contains('body: <streamed body>'));
      expect(output(), contains('body: <multipart body>'));
      expect(output(), isNot(contains('secret-stream')));
      expect(output(), isNot(contains('secret-field')));
    });

    test('prints the error type, status and message with the request uri', () {
      const error = ApiException(
        statusCode: 401,
        message: 'Unauthorized',
        type: ApiFailureType.auth,
      );

      final result = interceptor.onError(request(), error);

      expect(result, same(error));
      expect(output(), contains('*** ApiException ***'));
      expect(output(), contains('uri: https://api.example.com/me'));
      expect(output(), contains('type: ApiFailureType.auth'));
      expect(output(), contains('statusCode: 401'));
      expect(output(), contains('message: Unauthorized'));
      expect(output(), isNot(contains('test-token-value')));
    });

    test('omits the uri line when the error has no request', () {
      interceptor.onError(
        null,
        const ApiException(
          statusCode: 503,
          message: 'No internet connection',
          type: ApiFailureType.transport,
        ),
      );

      expect(output(), contains('*** ApiException ***'));
      expect(output(), isNot(contains('uri:')));
      expect(output(), contains('type: ApiFailureType.transport'));
      expect(output(), contains('statusCode: 503'));
    });
  });

  group('NetKitManager wiring', () {
    Iterable<RedactingLogInterceptor> registered(NetKitManager manager) =>
        manager.parameters.interceptors.whereType<RedactingLogInterceptor>();

    test('registers the redacting interceptor first in devMode', () {
      final manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: FakeTransport(),
        devMode: true,
        logInterceptorEnabled: true,
        sensitiveHeaders: const ['X-Tenant-Secret'],
        interceptors: [const _NoopInterceptor()],
      );
      addTearDown(manager.dispose);

      final redacting = registered(manager).single;
      expect(manager.parameters.interceptors.first, same(redacting));
      expect(manager.parameters.interceptors, hasLength(2));
      expect(redacting.sensitiveHeaders, contains('authorization'));
      expect(redacting.sensitiveHeaders, contains('x-tenant-secret'));
      expect(redacting.logBodies, isFalse);
      expect(manager.parameters.sensitiveHeaders, contains('x-tenant-secret'));
    });

    test('registers no log interceptor outside devMode', () {
      final manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: FakeTransport(),
        logInterceptorEnabled: true,
      );
      addTearDown(manager.dispose);

      expect(registered(manager), isEmpty);
    });

    test('registers no log interceptor when logInterceptorEnabled is false',
        () {
      final manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: FakeTransport(),
        devMode: true,
      );
      addTearDown(manager.dispose);

      expect(registered(manager), isEmpty);
    });

    test('logResponseBodies turns on body logging', () {
      final manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: FakeTransport(),
        devMode: true,
        logInterceptorEnabled: true,
        logResponseBodies: true,
      );
      addTearDown(manager.dispose);

      expect(registered(manager).single.logBodies, isTrue);
    });
  });
}

class _NoopInterceptor extends NetKitInterceptor {
  const _NoopInterceptor();
}
