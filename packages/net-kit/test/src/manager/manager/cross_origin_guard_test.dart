import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

/// Origin policy: `NetKitManager` talks to its configured API origin.
/// Other origins are blocked by default and never receive stored headers.
void main() {
  late FakeTransport transport;

  NetKitManager build({bool allowCrossOriginRequests = false}) {
    final manager = NetKitManager(
      baseUrl: 'https://api.example.com/v1',
      transport: transport,
      headers: {'X-Api-Key': 'api-key', 'Accept-Language': 'en'},
      allowCrossOriginRequests: allowCrossOriginRequests,
    )..setAccessToken('test-token');
    addTearDown(manager.dispose);
    return manager;
  }

  setUp(() {
    transport = FakeTransport()
      ..fallback = (_) => FakeTransport.jsonResponse(200, null);
  });

  group('default (allowCrossOriginRequests: false)', () {
    test('blocks an absolute URL on another origin before sending', () async {
      final manager = build();

      await expectLater(
        manager.requestVoid(
          path: 'https://storage.example.com/bucket/object?X-Signature=abc',
          method: RequestMethod.put,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.invalidRequest)
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.message,
                'message',
                const NetKitErrorParams().crossOriginRequestBlockedError,
              ),
        ),
      );
      expect(transport.requests, isEmpty);
    });

    test('blocks cross-origin uploads too', () async {
      final manager = build();

      await expectLater(
        manager.uploadRawData<VoidModel>(
          path: 'https://storage.example.com/bucket/object',
          model: VoidModel(),
          data: const [1, 2, 3],
          method: RequestMethod.put,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(transport.requests, isEmpty);
    });

    test('allows relative paths and same-origin absolute URLs', () async {
      final manager = build();

      await manager.requestVoid(path: '/me', method: RequestMethod.get);
      await manager.requestVoid(
        path: 'https://api.example.com/v2/me?x=1',
        method: RequestMethod.get,
      );
      await manager.requestVoid(
        path: 'HTTPS://API.EXAMPLE.COM:443/v3/me',
        method: RequestMethod.get,
      );

      expect(transport.requests, hasLength(3));
      expect(
        transport.requests.map((r) => r.headers['Authorization']),
        everyElement('Bearer test-token'),
      );
      expect(
        transport.requests.first.uri.toString(),
        'https://api.example.com/v1/me',
      );
    });

    test('uses the configured error message', () async {
      final manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: transport,
        errorParams: const NetKitErrorParams(
          crossOriginRequestBlockedError: 'Custom cross-origin message',
        ),
      );
      addTearDown(manager.dispose);

      await expectLater(
        manager.requestVoid(
          path: 'https://other.example.org/x',
          method: RequestMethod.get,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Custom cross-origin message',
          ),
        ),
      );
    });
  });

  group('allowCrossOriginRequests: true', () {
    test('sends the request without stored headers or the access token',
        () async {
      final manager = build(allowCrossOriginRequests: true);

      await manager.requestVoid(
        path: 'https://storage.example.com/bucket/object?X-Signature=abc',
        method: RequestMethod.put,
        headers: {'Content-Type': 'application/octet-stream'},
      );

      final sent = transport.lastRequest!;
      expect(
        sent.uri.toString(),
        'https://storage.example.com/bucket/object?X-Signature=abc',
      );
      expect(
        sent.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(sent.headers['X-Api-Key'], isNull);
      expect(sent.headers['Accept-Language'], isNull);
      expect(sent.headers['Content-Type'], 'application/octet-stream');
    });

    test('AuthPolicy.required cannot target another origin', () async {
      final manager = build(allowCrossOriginRequests: true);

      await expectLater(
        manager.requestVoid(
          path: 'https://storage.example.com/bucket/object',
          method: RequestMethod.get,
          authPolicy: AuthPolicy.required,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.invalidRequest),
        ),
      );
      expect(transport.requests, isEmpty);
    });

    test('same-origin requests still carry stored headers', () async {
      final manager = build(allowCrossOriginRequests: true);

      await manager.requestVoid(path: '/me', method: RequestMethod.get);

      final sent = transport.lastRequest!;
      expect(sent.headers['Authorization'], 'Bearer test-token');
      expect(sent.headers['X-Api-Key'], 'api-key');
    });
  });
}
