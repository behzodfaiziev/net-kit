import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

class _TestModel extends INetKitModel {
  const _TestModel();

  @override
  _TestModel fromJson(Map<String, dynamic> json) => const _TestModel();

  @override
  Map<String, dynamic>? toJson() => {};
}

/// `AuthPolicy.none` strips the access token from the outgoing request only;
/// the stored headers are never mutated, even under concurrent requests.
void main() {
  late FakeTransport transport;
  late NetKitManager manager;

  NetKitManager build({String accessTokenHeaderKey = 'Authorization'}) {
    final built = NetKitManager(
      baseUrl: 'https://api.example.com',
      transport: transport,
      accessTokenHeaderKey: accessTokenHeaderKey,
    )..setAccessToken('test-token');
    addTearDown(built.dispose);
    return built;
  }

  Future<void> get(
    String path, {
    AuthPolicy authPolicy = AuthPolicy.inherit,
    Map<String, String>? headers,
  }) {
    return manager.requestModel(
      path: path,
      method: RequestMethod.get,
      model: const _TestModel(),
      authPolicy: authPolicy,
      headers: headers,
      useDataKey: false,
    );
  }

  String? header(RawHttpRequest request, String name) {
    final lower = name.toLowerCase();
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == lower) {
        return entry.value;
      }
    }
    return null;
  }

  setUp(() {
    transport = FakeTransport()
      ..fallback = (_) => FakeTransport.jsonResponse(200, <String, dynamic>{});
    manager = build();
  });

  group('AuthPolicy header handling', () {
    test('concurrent none/inherit requests do not mutate stored headers',
        () async {
      await Future.wait([
        get('/public', authPolicy: AuthPolicy.none),
        get('/private'),
      ]);

      expect(manager.getAllHeaders()['Authorization'], 'Bearer test-token');

      final public =
          transport.requests.firstWhere((r) => r.uri.path == '/public');
      final private =
          transport.requests.firstWhere((r) => r.uri.path == '/private');
      expect(header(public, 'Authorization'), isNull);
      expect(header(private, 'Authorization'), 'Bearer test-token');
    });

    test('inherit (default) sends the token', () async {
      await get('/default-auth');

      expect(
        header(transport.lastRequest!, 'Authorization'),
        'Bearer test-token',
      );
    });

    test('none strips a custom access token header key', () async {
      manager = build(accessTokenHeaderKey: 'X-Auth-Token');

      await get('/custom', authPolicy: AuthPolicy.none);

      final sent = transport.lastRequest!;
      expect(header(sent, 'X-Auth-Token'), isNull);
      expect(header(sent, 'Authorization'), isNull);
      expect(manager.getAllHeaders()['X-Auth-Token'], 'Bearer test-token');
    });

    test('none preserves caller headers', () async {
      await get(
        '/custom-header',
        authPolicy: AuthPolicy.none,
        headers: {'X-Custom': '1'},
      );

      final sent = transport.lastRequest!;
      expect(header(sent, 'X-Custom'), '1');
      expect(header(sent, 'Authorization'), isNull);
    });

    test('none strips an access token header passed by the caller', () async {
      await get(
        '/caller-auth-header',
        authPolicy: AuthPolicy.none,
        headers: {'X-Custom': '1', 'authorization': 'Bearer caller-token'},
      );

      final sent = transport.lastRequest!;
      expect(header(sent, 'X-Custom'), '1');
      expect(header(sent, 'Authorization'), isNull);
    });

    test('stored token survives sequential none requests', () async {
      for (var i = 0; i < 3; i++) {
        await get('/public-$i', authPolicy: AuthPolicy.none);
        expect(manager.getAllHeaders()['Authorization'], 'Bearer test-token');
        expect(header(transport.lastRequest!, 'Authorization'), isNull);
      }
    });

    test('per-request headers override stored ones case-insensitively',
        () async {
      manager.addHeader(const MapEntry('X-Trace', 'stored'));

      await get('/trace', headers: {'x-trace': 'per-request'});

      final sent = transport.lastRequest!;
      final traceKeys =
          sent.headers.keys.where((k) => k.toLowerCase() == 'x-trace');
      expect(traceKeys, hasLength(1));
      expect(header(sent, 'X-Trace'), 'per-request');
      expect(manager.getAllHeaders()['X-Trace'], 'stored');
    });
  });
}
