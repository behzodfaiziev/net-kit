import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

/// `AuthPolicy` decides both whether the access token is attached and
/// whether a `401` triggers a refresh.
void main() {
  late FakeTransport transport;
  late NetKitManager manager;
  var refreshed = 0;
  var refreshCalls = 0;

  NetKitManager build({
    String? refreshTokenPath = '/auth/refresh',
    bool withToken = true,
  }) {
    final built = NetKitManager(
      baseUrl: 'https://api.example.com',
      transport: transport,
      refreshTokenPath: refreshTokenPath,
      onTokenRefreshed: (_) => refreshed++,
    )..setRefreshToken('refresh-token');
    if (withToken) {
      built.setAccessToken('old-token');
    }
    addTearDown(built.dispose);
    return built;
  }

  /// `/protected` answers `401` until the request carries the new token.
  void scriptProtected() {
    transport
      ..on(RawHttpMethod.get, '/protected', (request, _) {
        final auth = request.headers['Authorization'];
        if (auth == 'Bearer new-token') {
          return FakeTransport.jsonResponse(200, {'ok': true});
        }
        return FakeTransport.jsonResponse(401, {'message': 'expired'});
      })
      ..on(RawHttpMethod.post, '/auth/refresh', (_, __) {
        refreshCalls++;
        return FakeTransport.jsonResponse(200, {
          'accessToken': 'new-token',
          'refreshToken': 'new-refresh',
        });
      });
  }

  Iterable<RawHttpRequest> protectedCalls() =>
      transport.requests.where((r) => r.uri.path == '/protected');

  setUp(() {
    refreshed = 0;
    refreshCalls = 0;
    transport = FakeTransport();
    scriptProtected();
  });

  group('AuthPolicy.inherit', () {
    test('refreshes on 401 and retries the GET with the new token', () async {
      manager = build();

      await manager.requestVoid(path: '/protected', method: RequestMethod.get);

      expect(refreshCalls, 1);
      expect(refreshed, 1);
      expect(manager.getAllHeaders()['Authorization'], 'Bearer new-token');
      final calls = protectedCalls().toList();
      expect(calls, hasLength(2));
      expect(calls[0].headers['Authorization'], 'Bearer old-token');
      expect(calls[1].headers['Authorization'], 'Bearer new-token');
    });
  });

  group('AuthPolicy.none', () {
    test('never attaches the token and a 401 never refreshes', () async {
      manager = build();

      await expectLater(
        manager.requestVoid(
          path: '/protected',
          method: RequestMethod.get,
          authPolicy: AuthPolicy.none,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.response)
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'expired'),
        ),
      );

      expect(refreshCalls, 0);
      expect(refreshed, 0);
      expect(manager.getAllHeaders()['Authorization'], 'Bearer old-token');
      expect(transport.requests, hasLength(1));
      expect(transport.lastRequest!.headers['Authorization'], isNull);
    });
  });

  group('AuthPolicy.required', () {
    test('fails before sending when no token is stored', () async {
      manager = build(withToken: false);

      await expectLater(
        manager.requestVoid(
          path: '/protected',
          method: RequestMethod.get,
          authPolicy: AuthPolicy.required,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.auth)
              .having((e) => e.statusCode, 'statusCode', 401)
              .having(
                (e) => e.message,
                'message',
                const NetKitErrorParams().missingAccessTokenError,
              ),
        ),
      );
      expect(transport.requests, isEmpty);
      expect(refreshCalls, 0);
    });

    test('behaves like inherit when a token is stored', () async {
      manager = build();

      await manager.requestVoid(
        path: '/protected',
        method: RequestMethod.get,
        authPolicy: AuthPolicy.required,
      );

      expect(refreshCalls, 1);
      expect(protectedCalls(), hasLength(2));
      expect(
        transport.lastRequest!.headers['Authorization'],
        'Bearer new-token',
      );
    });
  });

  group('refreshTokenPath: null', () {
    test('returns the 401 as-is without attempting a refresh', () async {
      manager = build(refreshTokenPath: null);

      await expectLater(
        manager.requestVoid(path: '/protected', method: RequestMethod.get),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.response)
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );

      expect(refreshCalls, 0);
      expect(transport.requests, hasLength(1));
      expect(manager.getAllHeaders()['Authorization'], 'Bearer old-token');
    });
  });
}
