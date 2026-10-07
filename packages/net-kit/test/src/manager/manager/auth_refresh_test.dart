import 'dart:convert';

import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

/// Single-flight token refresh and the one retry that follows it.
void main() {
  late FakeTransport transport;
  late NetKitManager manager;
  late int refreshCalls;
  late List<AuthTokenModel> refreshedTokens;
  late List<ApiException> invalidations;

  NetKitManager build({
    bool removeAccessTokenBeforeRefresh = true,
    RefreshTokenContentType refreshTokenContentType =
        RefreshTokenContentType.json,
    void Function(NetKitRequestOptions options)? onBeforeRefreshRequest,
  }) {
    final built = NetKitManager(
      baseUrl: 'https://api.example.com',
      transport: transport,
      refreshTokenPath: '/auth/refresh',
      removeAccessTokenBeforeRefresh: removeAccessTokenBeforeRefresh,
      refreshTokenContentType: refreshTokenContentType,
      onBeforeRefreshRequest: onBeforeRefreshRequest,
      onTokenRefreshed: refreshedTokens.add,
      onSessionInvalidated: invalidations.add,
    )
      ..setAccessToken('old-token')
      ..setRefreshToken('refresh-token');
    addTearDown(built.dispose);
    return built;
  }

  RawHttpResponse protectedHandler(RawHttpRequest request, List<int>? _) {
    if (request.headers['Authorization'] == 'Bearer new-token') {
      return FakeTransport.jsonResponse(200, {'ok': true});
    }
    return FakeTransport.jsonResponse(401, {'message': 'expired'});
  }

  void scriptRefresh({int status = 200, Object? json}) {
    transport.on(RawHttpMethod.post, '/auth/refresh', (_, __) {
      refreshCalls++;
      return FakeTransport.jsonResponse(
        status,
        json ?? {'accessToken': 'new-token', 'refreshToken': 'new-refresh'},
      );
    });
  }

  Iterable<RawHttpRequest> requestsTo(String path) =>
      transport.requests.where((r) => r.uri.path == path);

  RawHttpRequest refreshRequest() => requestsTo('/auth/refresh').single;

  TypeMatcher<ApiException> failure(
    ApiFailureType type,
    int? statusCode,
    String message,
  ) =>
      isA<ApiException>()
          .having((e) => e.type, 'type', type)
          .having((e) => e.statusCode, 'statusCode', statusCode)
          .having((e) => e.message, 'message', message);

  Matcher authFailure(int? statusCode, String message) =>
      failure(ApiFailureType.auth, statusCode, message);

  setUp(() {
    refreshCalls = 0;
    refreshedTokens = [];
    invalidations = [];
    transport = FakeTransport()..on(null, '/protected', protectedHandler);
    scriptRefresh();
    manager = build();
  });

  group('successful refresh', () {
    test('single 401 refreshes once, retries, and updates the tokens',
        () async {
      await manager.requestVoid(path: '/protected', method: RequestMethod.get);

      expect(refreshCalls, 1);
      expect(refreshedTokens, hasLength(1));
      expect(refreshedTokens.single.accessToken, 'new-token');
      expect(refreshedTokens.single.refreshToken, 'new-refresh');
      expect(manager.getAllHeaders()['Authorization'], 'Bearer new-token');
      expect(requestsTo('/protected'), hasLength(2));
      expect(invalidations, isEmpty);
    });

    test('20 concurrent 401s share one refresh and all succeed', () async {
      await Future.wait([
        for (var i = 0; i < 20; i++)
          manager.requestVoid(
            path: '/protected',
            method: RequestMethod.get,
            queryParameters: {'i': i},
          ),
      ]);

      expect(refreshCalls, 1);
      expect(refreshedTokens, hasLength(1));
      final calls = requestsTo('/protected').toList();
      expect(calls, hasLength(40));
      expect(
        calls.where((r) => r.headers['Authorization'] == 'Bearer new-token'),
        hasLength(20),
      );
    });

    test('refresh body carries the refresh token and no Authorization',
        () async {
      await manager.requestVoid(path: '/protected', method: RequestMethod.get);

      final refresh = refreshRequest();
      expect(refresh.method, RawHttpMethod.post);
      expect(refresh.headers['Authorization'], isNull);
      expect(refresh.headers['Content-Type'], startsWith('application/json'));
      final index = transport.requests.indexOf(refresh);
      expect(
        jsonDecode(utf8.decode(transport.bodies[index]!)),
        {'refreshToken': 'refresh-token'},
      );
    });

    test('removeAccessTokenBeforeRefresh: false keeps the Authorization header',
        () async {
      manager = build(removeAccessTokenBeforeRefresh: false);

      await manager.requestVoid(path: '/protected', method: RequestMethod.get);

      expect(refreshRequest().headers['Authorization'], 'Bearer old-token');
    });

    test('formUrlEncoded refresh sends a form body', () async {
      manager = build(
        refreshTokenContentType: RefreshTokenContentType.formUrlEncoded,
      );

      await manager.requestVoid(path: '/protected', method: RequestMethod.get);

      final refresh = refreshRequest();
      expect(
        refresh.headers['Content-Type'],
        startsWith('application/x-www-form-urlencoded'),
      );
      final index = transport.requests.indexOf(refresh);
      expect(
        utf8.decode(transport.bodies[index]!),
        'refreshToken=refresh-token',
      );
    });

    test('onBeforeRefreshRequest can change path, headers, and body', () async {
      transport.on(RawHttpMethod.post, '/auth/renew', (_, __) {
        refreshCalls++;
        return FakeTransport.jsonResponse(200, {'accessToken': 'new-token'});
      });
      manager = build(
        onBeforeRefreshRequest: (options) {
          options
            ..path = '/auth/renew'
            ..headers['X-Client'] = 'mobile'
            ..data = {'token': 'refresh-token', 'grant': 'refresh'};
        },
      );

      await manager.requestVoid(path: '/protected', method: RequestMethod.get);

      expect(requestsTo('/auth/refresh'), isEmpty);
      final renew = requestsTo('/auth/renew').single;
      expect(renew.headers['X-Client'], 'mobile');
      final index = transport.requests.indexOf(renew);
      expect(
        jsonDecode(utf8.decode(transport.bodies[index]!)),
        {'token': 'refresh-token', 'grant': 'refresh'},
      );
      expect(manager.getAllHeaders()['Authorization'], 'Bearer new-token');
    });

    test('retried request carries the Idempotency-Key', () async {
      await manager.requestVoid(
        path: '/protected',
        method: RequestMethod.put,
        idempotencyKey: 'key-1',
      );

      final calls = requestsTo('/protected').toList();
      expect(calls, hasLength(2));
      expect(
        calls.map((r) => r.headers['Idempotency-Key']),
        ['key-1', 'key-1'],
      );
    });
  });

  group('failed refresh', () {
    test('a refresh 400 reaches every caller and keeps the session', () async {
      scriptRefresh(status: 400, json: {'message': 'invalid'});

      final results = await Future.wait([
        for (var i = 0; i < 5; i++)
          manager
              .requestVoid(path: '/protected', method: RequestMethod.get)
              .then<Object?>((_) => null, onError: (Object e) => e),
      ]);

      expect(
        results,
        everyElement(
          failure(ApiFailureType.response, 400, 'invalid')
              .having((e) => e.fromRefresh, 'fromRefresh', isTrue),
        ),
      );
      expect(refreshCalls, 1);
      expect(invalidations, isEmpty);
      expect(refreshedTokens, isEmpty);
      expect(manager.getAllHeaders()['Authorization'], 'Bearer old-token');
    });

    test('a refresh 2xx without accessToken is a decoding failure', () async {
      scriptRefresh(json: {'expiresIn': 3600});

      await expectLater(
        manager.requestVoid(path: '/protected', method: RequestMethod.get),
        throwsA(
          failure(
            ApiFailureType.decoding,
            200,
            const NetKitErrorParams().invalidTokenResponseError,
          ),
        ),
      );
      expect(invalidations, isEmpty);
      expect(refreshedTokens, isEmpty);
      expect(manager.getAllHeaders()['Authorization'], 'Bearer old-token');
    });

    test('a refresh 401 invalidates the session exactly once', () async {
      scriptRefresh(status: 401, json: {'message': 'refresh expired'});

      await expectLater(
        manager.requestVoid(path: '/protected', method: RequestMethod.get),
        throwsA(
          failure(
            ApiFailureType.sessionInvalidated,
            401,
            'refresh expired',
          ),
        ),
      );
      expect(refreshCalls, 1);
      expect(requestsTo('/protected'), hasLength(1));
      expect(invalidations, hasLength(1));
      expect(manager.getAllHeaders()['Authorization'], isNull);
    });

    test('a request to the refresh path getting 401 is not retried', () async {
      scriptRefresh(status: 401, json: {'message': 'nope'});

      await expectLater(
        manager.requestVoid(path: '/auth/refresh', method: RequestMethod.post),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.response)
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      expect(refreshCalls, 1);
      expect(invalidations, isEmpty);
    });
  });

  group('retry rules', () {
    test('POST 401 refreshes but is not replayed without allowRetryOn401',
        () async {
      await expectLater(
        manager.requestVoid(path: '/protected', method: RequestMethod.post),
        throwsA(
          authFailure(
            401,
            const NetKitErrorParams().nonIdempotentRetryBlockedError,
          ),
        ),
      );
      expect(refreshCalls, 1);
      expect(requestsTo('/protected'), hasLength(1));
      expect(manager.getAllHeaders()['Authorization'], 'Bearer new-token');
    });

    test('POST with allowRetryOn401 replays once', () async {
      await manager.requestVoid(
        path: '/protected',
        method: RequestMethod.post,
        body: {'a': 1},
        allowRetryOn401: true,
      );

      expect(refreshCalls, 1);
      final calls = requestsTo('/protected').toList();
      expect(calls, hasLength(2));
      expect(calls.last.headers['Authorization'], 'Bearer new-token');
      expect(calls.last.body, isA<BytesRawHttpBody>());
    });

    test('403 does not refresh', () async {
      transport.onGet('/forbidden', status: 403, json: {'message': 'no'});

      await expectLater(
        manager.requestVoid(path: '/forbidden', method: RequestMethod.get),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.response)
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
      expect(refreshCalls, 0);
    });

    test('a second 401 after the retry is returned to the caller', () async {
      transport.onGet('/always-401', status: 401, json: {'message': 'still'});

      await expectLater(
        manager.requestVoid(path: '/always-401', method: RequestMethod.get),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.response)
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'still'),
        ),
      );
      expect(refreshCalls, 1);
      expect(requestsTo('/always-401'), hasLength(2));
    });

    test('cancellation during the refresh yields a cancelled error', () async {
      final token = NetKitCancellationToken();
      transport.on(RawHttpMethod.post, '/auth/refresh', (_, __) {
        refreshCalls++;
        token.cancel();
        return FakeTransport.jsonResponse(200, {'accessToken': 'new-token'});
      });

      await expectLater(
        manager.requestVoid(
          path: '/protected',
          method: RequestMethod.get,
          cancellationToken: token,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.cancelled)
              .having((e) => e.statusCode, 'statusCode', isNull),
        ),
      );
      expect(refreshCalls, 1);
      expect(requestsTo('/protected'), hasLength(1));
    });
  });
}
