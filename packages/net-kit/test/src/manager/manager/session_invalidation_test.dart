import 'dart:async';
import 'dart:convert';

import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/core/net_kit_cancellation_token.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

/// Session invariant: the session is invalidated (tokens cleared,
/// `onSessionInvalidated` called) only when the refresh endpoint itself
/// answers HTTP 401. Every other outcome keeps the session usable.
typedef _Reply = FutureOr<RawHttpResponse> Function(
  RawHttpRequest request,
  List<int>? body,
);

RawHttpResponse _json(int status, [Object? body]) =>
    FakeTransport.jsonResponse(status, body);

_Reply _status(int status, [Object? body]) => (_, __) => _json(status, body);

_Reply _throws(RawHttpFailureType type) =>
    (request, _) => throw RawHttpException(
          message: type.name,
          type: type,
          uri: request.uri,
        );

const _newTokens = {'accessToken': 'new-token', 'refreshToken': 'new-refresh'};

/// `/resource` answers 401 until the request carries the refreshed token.
RawHttpResponse _protected(RawHttpRequest request, List<int>? _) {
  return request.headers['Authorization'] == 'Bearer new-token'
      ? _json(200, {'ok': true})
      : _json(401, {'message': 'expired'});
}

class _Harness {
  _Harness({
    String? refreshTokenPath = '/auth/refresh',
    bool allowCrossOriginRequests = false,
    void Function(NetKitRequestOptions options)? onBeforeRefreshRequest,
    OnSessionInvalidated? onSessionInvalidated,
    List<NetKitInterceptor> interceptors = const [],
  }) {
    manager = NetKitManager(
      baseUrl: 'https://api.example.com',
      transport: transport,
      refreshTokenPath: refreshTokenPath,
      allowCrossOriginRequests: allowCrossOriginRequests,
      internetStatusStream: connectivity.stream,
      interceptors: interceptors,
      onBeforeRefreshRequest: (options) {
        if (offlineDuringRefresh) {
          connectivity.add(false);
        }
        onBeforeRefreshRequest?.call(options);
      },
      onTokenRefreshed: refreshed.add,
      onSessionInvalidated: (exception) {
        invalidations.add(exception);
        return onSessionInvalidated?.call(exception);
      },
    )
      ..setAccessToken('old-token')
      ..setRefreshToken('refresh-token');
    transport.on(RawHttpMethod.post, '/auth/refresh', (request, body) {
      refreshCalls++;
      refreshBodies.add(body == null ? '' : utf8.decode(body));
      return refreshReply(request, body);
    });
  }

  final transport = FakeTransport();
  final connectivity = StreamController<bool>.broadcast();
  late final NetKitManager manager;
  final invalidations = <ApiException>[];
  final refreshed = <AuthTokenModel>[];
  final refreshBodies = <String>[];
  int refreshCalls = 0;
  bool offlineDuringRefresh = false;
  _Reply refreshReply = _status(200, _newTokens);

  String? get authorization => manager.getAllHeaders()['Authorization'];

  int callsTo(String path) =>
      transport.requests.where((r) => r.uri.path == path).length;

  Future<Object?> get(String path, {NetKitCancellationToken? token}) {
    return manager
        .requestVoid(
          path: path,
          method: RequestMethod.get,
          cancellationToken: token,
        )
        .then<Object?>((_) => null, onError: (Object error) => error);
  }

  Future<void> dispose() async {
    manager.dispose();
    await connectivity.close();
  }
}

class _Row {
  const _Row(
    this.name, {
    required this.original,
    required this.expectedType,
    required this.retried,
    required this.invalidated,
    this.refresh,
    this.offlineDuringRefresh = false,
    this.offlineBeforeRequest = false,
    this.expectedStatus,
  });

  final String name;
  final _Reply original;
  final _Reply? refresh;
  final bool offlineDuringRefresh;
  final bool offlineBeforeRequest;

  /// `null` when the request is expected to succeed.
  final ApiFailureType? expectedType;
  final int? expectedStatus;
  final bool retried;
  final bool invalidated;

  bool get refreshes => refresh != null || offlineDuringRefresh;
}

final _matrix = <_Row>[
  _Row(
    '200 | n/a',
    original: _status(200, {'ok': true}),
    expectedType: null,
    retried: false,
    invalidated: false,
  ),
  _Row(
    '401 | refresh 200 + token',
    original: _protected,
    refresh: _status(200, _newTokens),
    expectedType: null,
    retried: true,
    invalidated: false,
  ),
  _Row(
    '401 | refresh 401',
    original: _protected,
    refresh: _status(401, {'message': 'refresh rejected'}),
    expectedType: ApiFailureType.sessionInvalidated,
    expectedStatus: 401,
    retried: false,
    invalidated: true,
  ),
  for (final status in [400, 403, 404, 409, 422, 429, 500, 502, 503, 504])
    _Row(
      '401 | refresh $status',
      original: _protected,
      refresh: _status(status, {'message': 'refresh $status'}),
      expectedType: ApiFailureType.response,
      expectedStatus: status,
      retried: false,
      invalidated: false,
    ),
  _Row(
    '401 | socket offline',
    original: _protected,
    refresh: _throws(RawHttpFailureType.connection),
    expectedType: ApiFailureType.transport,
    retried: false,
    invalidated: false,
  ),
  const _Row(
    '401 | device offline (internet status)',
    original: _protected,
    offlineDuringRefresh: true,
    expectedType: ApiFailureType.transport,
    expectedStatus: 503,
    retried: false,
    invalidated: false,
  ),
  _Row(
    '401 | DNS failure',
    original: _protected,
    refresh: (request, _) => throw RawHttpException(
      message: 'Failed host lookup: api.example.com',
      type: RawHttpFailureType.connection,
      uri: request.uri,
    ),
    expectedType: ApiFailureType.transport,
    retried: false,
    invalidated: false,
  ),
  _Row(
    '401 | TLS failure',
    original: _protected,
    refresh: _throws(RawHttpFailureType.tls),
    expectedType: ApiFailureType.transport,
    retried: false,
    invalidated: false,
  ),
  _Row(
    '401 | timeout',
    original: _protected,
    refresh: _throws(RawHttpFailureType.timeout),
    expectedType: ApiFailureType.timeout,
    expectedStatus: 408,
    retried: false,
    invalidated: false,
  ),
  _Row(
    '401 | cancelled',
    original: _protected,
    refresh: _throws(RawHttpFailureType.cancellation),
    expectedType: ApiFailureType.cancelled,
    retried: false,
    invalidated: false,
  ),
  _Row(
    '401 | invalid transport response',
    original: _protected,
    refresh: _throws(RawHttpFailureType.invalidResponse),
    expectedType: ApiFailureType.transport,
    retried: false,
    invalidated: false,
  ),
  _Row(
    '401 | malformed body',
    original: _protected,
    refresh: (_, __) => RawHttpResponse(
      statusCode: 200,
      headers: const {
        'content-type': ['application/json'],
      },
      bodyBytes: utf8.encode('{"accessToken": '),
    ),
    expectedType: ApiFailureType.decoding,
    expectedStatus: 200,
    retried: false,
    invalidated: false,
  ),
  _Row(
    '401 | 200 without token',
    original: _protected,
    refresh: _status(200, {'expiresIn': 60}),
    expectedType: ApiFailureType.decoding,
    expectedStatus: 200,
    retried: false,
    invalidated: false,
  ),
  _Row(
    '500 original | n/a',
    original: _status(500, {'message': 'boom'}),
    expectedType: ApiFailureType.response,
    expectedStatus: 500,
    retried: false,
    invalidated: false,
  ),
  _Row(
    '403 original | n/a',
    original: _status(403, {'message': 'no'}),
    expectedType: ApiFailureType.response,
    expectedStatus: 403,
    retried: false,
    invalidated: false,
  ),
  _Row(
    'timeout original | n/a',
    original: _throws(RawHttpFailureType.timeout),
    expectedType: ApiFailureType.timeout,
    retried: false,
    invalidated: false,
  ),
  _Row(
    'offline original | n/a',
    original: _status(200),
    offlineBeforeRequest: true,
    expectedType: ApiFailureType.transport,
    expectedStatus: 503,
    retried: false,
    invalidated: false,
  ),
];

void main() {
  group('session invalidation matrix', () {
    for (final row in _matrix) {
      test(row.name, () async {
        final h = _Harness();
        addTearDown(h.dispose);
        h
          ..transport.on(null, '/resource', row.original)
          ..offlineDuringRefresh = row.offlineDuringRefresh;
        if (row.refresh != null) {
          h.refreshReply = row.refresh!;
        }
        if (row.offlineBeforeRequest) {
          h.connectivity.add(false);
          await Future<void>.delayed(Duration.zero);
        }

        final result = await h.get('/resource');

        if (row.expectedType == null) {
          expect(result, isNull);
        } else {
          expect(
            result,
            isA<ApiException>()
                .having((e) => e.type, 'type', row.expectedType)
                .having(
                  (e) => e.fromRefresh,
                  'fromRefresh',
                  row.refreshes && !row.retried,
                ),
          );
          if (row.expectedStatus != null) {
            expect((result! as ApiException).statusCode, row.expectedStatus);
          }
        }

        final fetchedRefresh = row.refresh != null;
        expect(h.refreshCalls, fetchedRefresh ? 1 : 0, reason: 'refreshes');
        final expectedResourceCalls =
            row.offlineBeforeRequest ? 0 : (row.retried ? 2 : 1);
        expect(h.callsTo('/resource'), expectedResourceCalls, reason: 'retry');
        expect(
          h.invalidations,
          hasLength(row.invalidated ? 1 : 0),
          reason: 'session invalidation',
        );

        if (row.invalidated) {
          expect(h.authorization, isNull);
        } else if (row.retried) {
          expect(h.authorization, 'Bearer new-token');
        } else {
          // Session preserved: the stored token is untouched and a later
          // refresh still sends the stored refresh token.
          expect(h.authorization, 'Bearer old-token');
          if (row.refreshes) {
            h
              ..connectivity.add(true)
              ..offlineDuringRefresh = false
              ..refreshReply = _status(200, _newTokens)
              ..transport.on(null, '/resource', _protected);
            await Future<void>.delayed(Duration.zero);
            expect(await h.get('/resource'), isNull);
            expect(h.refreshBodies.last, contains('refresh-token'));
            expect(h.authorization, 'Bearer new-token');
            expect(h.invalidations, isEmpty);
          }
        }
      });
    }
  });

  group('no refresh-endpoint 401, no invalidation', () {
    test('callback count stays zero across every non-401 failure', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.transport.on(null, '/resource', _protected);

      final replies = <_Reply>[
        _status(400),
        _status(403),
        _status(429),
        _status(500),
        _status(503),
        _status(200, {'nothing': true}),
        _throws(RawHttpFailureType.connection),
        _throws(RawHttpFailureType.tls),
        _throws(RawHttpFailureType.timeout),
        _throws(RawHttpFailureType.cancellation),
        _throws(RawHttpFailureType.invalidResponse),
        _throws(RawHttpFailureType.unknown),
      ];
      for (final reply in replies) {
        h.refreshReply = reply;
        expect(await h.get('/resource'), isA<ApiException>());
      }
      h.offlineDuringRefresh = true;
      expect(await h.get('/resource'), isA<ApiException>());

      expect(h.invalidations, isEmpty);
      expect(h.authorization, 'Bearer old-token');
    });

    test('no refreshTokenPath: a 401 surfaces as-is and nothing is cleared',
        () async {
      final h = _Harness(refreshTokenPath: null);
      addTearDown(h.dispose);
      h.transport.on(null, '/resource', _protected);

      final result = await h.get('/resource');

      expect(
        result,
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiFailureType.response)
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.fromRefresh, 'fromRefresh', isFalse),
      );
      expect(h.refreshCalls, 0);
      expect(h.invalidations, isEmpty);
      expect(h.authorization, 'Bearer old-token');
    });

    test('AuthPolicy.none 401 never refreshes or invalidates', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h
        ..transport.on(null, '/resource', _protected)
        ..refreshReply = _status(401);

      await expectLater(
        h.manager.requestVoid(
          path: '/resource',
          method: RequestMethod.get,
          authPolicy: AuthPolicy.none,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.response),
        ),
      );
      expect(h.refreshCalls, 0);
      expect(h.invalidations, isEmpty);
    });

    test('AuthPolicy.required without a token sends nothing', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.manager.removeAccessToken();

      await expectLater(
        h.manager.requestVoid(
          path: '/resource',
          method: RequestMethod.get,
          authPolicy: AuthPolicy.required,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.auth),
        ),
      );
      expect(h.transport.requests, isEmpty);
      expect(h.invalidations, isEmpty);
    });

    test('an interceptor turning a refresh 503 into 401 does not invalidate',
        () async {
      final h = _Harness(interceptors: const [_RewriteRefreshStatus(503, 401)]);
      addTearDown(h.dispose);
      h
        ..transport.on(null, '/resource', _protected)
        ..refreshReply = _status(503, {'message': 'down'});

      final result = await h.get('/resource');

      expect(
        result,
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiFailureType.response),
      );
      expect(h.invalidations, isEmpty);
      expect(h.authorization, 'Bearer old-token');
    });

    test('the raw transport returns 401 without touching the session',
        () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.transport.onGet('/object', status: 401);

      final response = await h.manager.transport.send(
        RawHttpRequest(
          uri: Uri.parse('https://storage.example.com/object'),
          method: RawHttpMethod.get,
        ),
      );

      expect(response.statusCode, 401);
      expect(response.headers, isNot(contains('authorization')));
      expect(h.transport.lastRequest!.headers, isEmpty);
      expect(h.refreshCalls, 0);
      expect(h.invalidations, isEmpty);
    });
  });

  group('terminal refresh 401', () {
    test('10 concurrent 401s: one refresh, one callback, ten equal failures',
        () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final gate = Completer<void>();
      h
        ..transport.on(null, '/resource', _protected)
        ..refreshReply = (_, __) async {
          await gate.future;
          return _json(401, {'message': 'refresh rejected'});
        };

      final pending = [for (var i = 0; i < 10; i++) h.get('/resource')];
      await Future<void>.delayed(const Duration(milliseconds: 10));
      gate.complete();
      final results = await Future.wait(pending);

      expect(h.refreshCalls, 1);
      expect(h.invalidations, hasLength(1));
      expect(
        results,
        everyElement(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.sessionInvalidated)
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'refresh rejected'),
        ),
      );
      expect(h.callsTo('/resource'), 10);
      expect(h.authorization, isNull);
    });

    test('later 401s after invalidation do not refresh or call back again',
        () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h
        ..transport.on(null, '/resource', _protected)
        ..refreshReply = _status(401);

      await h.get('/resource');
      final later = await h.get('/resource');

      expect(h.refreshCalls, 1);
      expect(h.invalidations, hasLength(1));
      expect(
        later,
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiFailureType.response)
            .having((e) => e.statusCode, 'statusCode', 401),
      );
    });

    test('signing in again re-enables refresh', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h
        ..transport.on(null, '/resource', _protected)
        ..refreshReply = _status(401);
      await h.get('/resource');

      h
        ..manager.setAccessToken('fresh-login')
        ..manager.setRefreshToken('refresh-2')
        ..refreshReply = _status(200, _newTokens);

      expect(await h.get('/resource'), isNull);
      expect(h.refreshCalls, 2);
      expect(h.refreshBodies.last, contains('refresh-2'));
      expect(h.invalidations, hasLength(1));
    });

    test('a throwing callback does not leave the refresh stuck', () async {
      final h = _Harness(
        onSessionInvalidated: (_) => throw StateError('callback failed'),
      );
      addTearDown(h.dispose);
      h
        ..transport.on(null, '/resource', _protected)
        ..refreshReply = _status(401);

      final results =
          await Future.wait([h.get('/resource'), h.get('/resource')]);

      expect(
        results,
        everyElement(
          isA<ApiException>().having(
            (e) => e.type,
            'type',
            ApiFailureType.sessionInvalidated,
          ),
        ),
      );
      h
        ..manager.setRefreshToken('refresh-2')
        ..refreshReply = _status(200, _newTokens);
      expect(await h.get('/resource'), isNull);
      expect(h.refreshCalls, 2);
    });

    test('an async callback that fails does not surface or block', () async {
      final h = _Harness(
        onSessionInvalidated: (_) async {
          await Future<void>.delayed(Duration.zero);
          throw StateError('async callback failed');
        },
      );
      addTearDown(h.dispose);
      h
        ..transport.on(null, '/resource', _protected)
        ..refreshReply = _status(401);

      final result = await h.get('/resource');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(
        result,
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiFailureType.sessionInvalidated),
      );
      expect(h.invalidations, hasLength(1));
    });

    test('the callback may use the manager re-entrantly', () async {
      late _Harness h;
      Object? reentrant = 'not run';
      h = _Harness(
        onSessionInvalidated: (_) async {
          reentrant = await h.manager
              .requestVoid(
                path: '/public',
                method: RequestMethod.get,
                authPolicy: AuthPolicy.none,
              )
              .then<Object?>((_) => null, onError: (Object e) => e);
        },
      );
      addTearDown(h.dispose);
      h
        ..transport.on(null, '/resource', _protected)
        ..transport.onGet('/public', json: {'ok': true})
        ..refreshReply = _status(401);

      await h.get('/resource');
      for (var i = 0; i < 20 && reentrant == 'not run'; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(reentrant, isNull);
      expect(h.invalidations, hasLength(1));
    });
  });

  group('session survives transient refresh failure', () {
    test('offline refresh, then recovery with a new refresh', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h
        ..transport.on(null, '/resource', _protected)
        ..refreshReply = _throws(RawHttpFailureType.connection);

      final offline = await h.get('/resource');
      expect(
        offline,
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiFailureType.transport)
            .having((e) => e.fromRefresh, 'fromRefresh', isTrue),
      );
      expect(h.authorization, 'Bearer old-token');
      expect(h.invalidations, isEmpty);

      h.refreshReply = _status(200, _newTokens);
      expect(await h.get('/resource'), isNull);

      expect(h.refreshCalls, 2);
      expect(h.refreshBodies, everyElement(contains('refresh-token')));
      expect(h.authorization, 'Bearer new-token');
      expect(h.invalidations, isEmpty);
    });

    test('the refresh request never removes the stored access token', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      String? storedDuringRefresh;
      h
        ..transport.on(null, '/resource', _protected)
        ..refreshReply = (request, _) {
          storedDuringRefresh = h.authorization;
          expect(request.headers['Authorization'], isNull);
          return _json(503);
        };

      await h.get('/resource');

      expect(storedDuringRefresh, 'Bearer old-token');
      expect(h.authorization, 'Bearer old-token');
    });
  });

  group('races', () {
    test('a token set during the refresh is not overwritten', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final gate = Completer<void>();
      h
        ..transport.on(null, '/resource', (request, body) {
          final auth = request.headers['Authorization'];
          return auth == 'Bearer manual-token' || auth == 'Bearer new-token'
              ? _json(200, {'ok': true})
              : _json(401);
        })
        ..refreshReply = (_, __) async {
          await gate.future;
          return _json(200, _newTokens);
        };

      final pending = h.get('/resource');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      h.manager.setAccessToken('manual-token');
      gate.complete();

      expect(await pending, isNull);
      expect(h.authorization, 'Bearer manual-token');
      expect(h.refreshed, isEmpty);
      final retried =
          h.transport.requests.where((r) => r.uri.path == '/resource');
      expect(retried.last.headers['Authorization'], 'Bearer manual-token');
    });

    test('a refresh 401 for superseded credentials does not invalidate',
        () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final gate = Completer<void>();
      h
        ..transport.on(null, '/resource', (request, body) {
          return request.headers['Authorization'] == 'Bearer manual-token'
              ? _json(200, {'ok': true})
              : _json(401);
        })
        ..refreshReply = (_, __) async {
          await gate.future;
          return _json(401);
        };

      final pending = h.get('/resource');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      h.manager
        ..setAccessToken('manual-token')
        ..setRefreshToken('refresh-2');
      gate.complete();

      expect(await pending, isNull);
      expect(h.invalidations, isEmpty);
      expect(h.authorization, 'Bearer manual-token');
    });

    test('cancelling one waiter keeps the shared refresh for the others',
        () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final gate = Completer<void>();
      h
        ..transport.on(null, '/resource', _protected)
        ..refreshReply = (_, __) async {
          await gate.future;
          return _json(200, _newTokens);
        };
      final token = NetKitCancellationToken();

      final cancelled = h.get('/resource', token: token);
      final other = h.get('/resource');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      token.cancel();

      expect(
        await cancelled,
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiFailureType.cancelled),
      );
      expect(h.refreshCalls, 1);
      gate.complete();
      expect(await other, isNull);

      expect(h.refreshCalls, 1);
      expect(h.callsTo('/resource'), 3, reason: 'cancelled one never retries');
      expect(netKitCancellationBindingCount(token), 0);
      expect(h.authorization, 'Bearer new-token');
    });

    test('AuthPolicy.none during a refresh sends no token', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final gate = Completer<void>();
      h
        ..transport.on(null, '/resource', _protected)
        ..transport.onGet('/public', json: {'ok': true})
        ..refreshReply = (_, __) async {
          await gate.future;
          return _json(200, _newTokens);
        };

      final pending = h.get('/resource');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await h.manager.requestVoid(
        path: '/public',
        method: RequestMethod.get,
        authPolicy: AuthPolicy.none,
      );
      gate.complete();
      await pending;

      final public = h.transport.requests.singleWhere(
        (r) => r.uri.path == '/public',
      );
      expect(public.headers['Authorization'], isNull);
    });

    test('a transient failure followed by a later 401 starts a new refresh',
        () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h
        ..transport.on(null, '/resource', _protected)
        ..refreshReply = _status(500);

      await h.get('/resource');
      await h.get('/resource');

      expect(h.refreshCalls, 2);
      expect(h.invalidations, isEmpty);
    });
  });

  group('refresh origin and redirects', () {
    test('onBeforeRefreshRequest cannot move the refresh to another origin',
        () async {
      for (final allow in [false, true]) {
        final h = _Harness(
          allowCrossOriginRequests: allow,
          onBeforeRefreshRequest: (options) =>
              options.path = 'https://other.example.org/auth/refresh',
        );
        addTearDown(h.dispose);
        h.transport.on(null, '/resource', _protected);

        final result = await h.get('/resource');

        expect(
          result,
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.invalidRequest)
              .having((e) => e.fromRefresh, 'fromRefresh', isTrue),
        );
        expect(
          h.transport.requests.where((r) => r.uri.host != 'api.example.com'),
          isEmpty,
        );
        expect(h.invalidations, isEmpty);
        expect(h.authorization, 'Bearer old-token');
      }
    });

    for (final status in [307, 308]) {
      test('same-origin $status redirect is followed with the body', () async {
        final h = _Harness();
        addTearDown(h.dispose);
        h
          ..transport.on(null, '/resource', _protected)
          ..refreshReply = _status(status)
          ..transport.on(RawHttpMethod.post, '/auth/refresh', (_, __) {
            h.refreshCalls++;
            return RawHttpResponse(
              statusCode: status,
              headers: const {
                'location': ['/auth/refresh-v2'],
              },
            );
          })
          ..transport.on(
            RawHttpMethod.post,
            '/auth/refresh-v2',
            (_, body) {
              h.refreshBodies.add(utf8.decode(body!));
              return _json(200, _newTokens);
            },
          );

        expect(await h.get('/resource'), isNull);
        expect(h.refreshBodies.single, contains('refresh-token'));
        expect(h.authorization, 'Bearer new-token');
      });
    }

    for (final status in [301, 302, 303, 307, 308]) {
      for (final allow in [false, true]) {
        test(
            'cross-origin $status refresh redirect is rejected '
            '(allowCrossOriginRequests: $allow)', () async {
          final h = _Harness(allowCrossOriginRequests: allow);
          addTearDown(h.dispose);
          h
            ..transport.on(null, '/resource', _protected)
            ..transport.onAny(
              'https://other.example.org/steal',
              json: _newTokens,
            )
            ..refreshReply = ((_, __) => RawHttpResponse(
                  statusCode: status,
                  headers: const {
                    'location': ['https://other.example.org/steal'],
                  },
                ));

          final result = await h.get('/resource');

          expect(
            result,
            isA<ApiException>()
                .having((e) => e.type, 'type', ApiFailureType.invalidRequest),
          );
          expect(
            h.transport.requests.where((r) => r.uri.host != 'api.example.com'),
            isEmpty,
            reason: 'no refresh credential leaves the API origin',
          );
          expect(h.invalidations, isEmpty);
          expect(h.authorization, 'Bearer old-token');
        });
      }
    }

    test('an interceptor cannot move the refresh request off the API origin',
        () async {
      final h = _Harness(
        allowCrossOriginRequests: true,
        interceptors: const [
          _MoveTo('https://other.example.org', onlyPath: '/auth/refresh'),
        ],
      );
      addTearDown(h.dispose);
      h.transport.on(null, '/resource', _protected);

      final result = await h.get('/resource');

      expect(
        result,
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiFailureType.invalidRequest),
      );
      expect(
        h.transport.requests.where((r) => r.uri.host != 'api.example.com'),
        isEmpty,
      );
      expect(h.invalidations, isEmpty);
    });

    test('an interceptor moving a request elsewhere drops stored credentials',
        () async {
      final h = _Harness(
        allowCrossOriginRequests: true,
        interceptors: const [_MoveTo('https://other.example.org')],
      );
      addTearDown(h.dispose);
      h.transport.onAny('https://other.example.org/resource', json: {});

      await h.manager.requestVoid(
        path: '/resource',
        method: RequestMethod.get,
        headers: {'X-Trace': 'abc'},
      );

      final sent = h.transport.lastRequest!;
      expect(sent.uri.host, 'other.example.org');
      expect(sent.headers['Authorization'], isNull);
      expect(sent.headers['X-Trace'], 'abc');
    });

    test('a refresh response from a client-followed redirect is rejected',
        () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h
        ..transport.on(null, '/resource', _protected)
        ..refreshReply = (_, __) => RawHttpResponse(
              statusCode: 200,
              headers: const {
                'content-type': ['application/json'],
              },
              bodyBytes: utf8.encode(jsonEncode(_newTokens)),
              redirected: true,
            );

      final result = await h.get('/resource');

      expect(
        result,
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiFailureType.invalidRequest)
            .having(
              (e) => e.message,
              'message',
              const NetKitErrorParams().unverifiedRedirectError,
            ),
      );
      expect(h.refreshed, isEmpty);
      expect(h.authorization, 'Bearer old-token');
      expect(h.invalidations, isEmpty);
    });
  });
}

/// Rewrites the status of refresh responses, to prove the session decision
/// uses the transport status rather than an interceptor's replacement.
class _RewriteRefreshStatus extends NetKitInterceptor {
  const _RewriteRefreshStatus(this.from, this.to);

  final int from;
  final int to;

  @override
  RawHttpResponse onResponse(RawHttpRequest request, RawHttpResponse response) {
    if (request.uri.path != '/auth/refresh' || response.statusCode != from) {
      return response;
    }
    return RawHttpResponse(
      statusCode: to,
      headers: response.headers,
      bodyBytes: response.bodyBytes,
    );
  }
}

/// Rewrites requests (all, or those on [onlyPath]) to [origin].
class _MoveTo extends NetKitInterceptor {
  const _MoveTo(this.origin, {this.onlyPath});

  final String origin;
  final String? onlyPath;

  @override
  RawHttpRequest onRequest(RawHttpRequest request) {
    if (onlyPath != null && request.uri.path != onlyPath) {
      return request;
    }
    final target = Uri.parse(origin);
    return request.copyWith(
      uri: request.uri.replace(scheme: target.scheme, host: target.host),
    );
  }
}
