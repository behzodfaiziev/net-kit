import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:net_kit/net_kit.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import 'logger.dart';
import 'mock_backend.dart';

class DummyModel extends INetKitModel {
  const DummyModel();

  @override
  DummyModel fromJson(Map<String, dynamic> json) => const DummyModel();

  @override
  Map<String, dynamic> toJson() => {};
}

class TestAuthLocalStorageService {
  String? _accessToken;
  String? _refreshToken;

  bool skipSetRefreshToken = false; // NEW: control behavior

  Future<void> setAccessToken(String? value) async {
    _accessToken = value;
  }

  Future<void> setRefreshToken(String? value) async {
    if (skipSetRefreshToken) return; // Ignore if flag is set
    _refreshToken = value;
  }

  Future<String?> getAccessToken() async => _accessToken;

  Future<String?> getRefreshToken() async => _refreshToken;
}

void main() {
  late HttpServer server;
  late Uri baseUrl;
  late TestBackendState backendState;
  late TestAuthLocalStorageService authStorage;
  late NetKitManager netKitManager;

  NetKitManager createNetKitManagerWithStorage(
    TestAuthLocalStorageService storage,
  ) {
    final manager = NetKitManager(
      baseUrl: 'http://localhost:${server.port}',
      refreshTokenPath: '/api/refresh',
      dataKey: 'data',
      onTokenRefreshed: (token) {
        storage.setAccessToken(token.accessToken ?? '');
        if (token.refreshToken != null) {
          storage.setRefreshToken(token.refreshToken);
        }
      },
      // ... other required params ...
    );
    // Restore tokens from storage if present
    storage.getAccessToken().then(manager.setAccessToken);
    storage.getRefreshToken().then(manager.setRefreshToken);
    return manager;
  }

  setUp(() async {
    backendState = TestBackendState();
    server = await shelf_io.serve(
      buildBackendHandler(backendState),
      InternetAddress.loopbackIPv4,
      0,
    );

    baseUrl = Uri.parse('http://localhost:${server.port}');

    authStorage = TestAuthLocalStorageService();
    await authStorage.setAccessToken('expired');
    await authStorage.setRefreshToken(backendState.refreshToken);

    netKitManager = NetKitManager(
      baseUrl: baseUrl.toString(),
      refreshTokenPath: '/api/refresh',
      dataKey: 'data',
      logger: RefreshLogger(),
      internetStatusStream: Stream.value(true),
      onTokenRefreshed: (token) async {
        await authStorage.setAccessToken(token.accessToken);
        if (token.refreshToken != null) {
          await authStorage.setRefreshToken(token.refreshToken);
        }
      },
    );
  });

  tearDown(() async {
    await server.close();
  });

  group('Refresh Token Integration Test', () {
    test('Single request triggers refresh and succeeds', () async {
      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);
      try {
        final result = await netKitManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        );
        expect(result, isA<DummyModel>());
        expect(backendState.refreshCallCount, 1);
        expect(await authStorage.getAccessToken(), backendState.accessToken);
        expect(await authStorage.getRefreshToken(), backendState.refreshToken);
      } on ApiException catch (e) {
        fail('Request failed with error: ${e.message}');
      }
    });

    test('Multiple parallel requests trigger only one refresh', () async {
      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      // Prepare four parallel API requests (all require valid access token)
      final requests = [
        netKitManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        ),
        netKitManager.requestModel<DummyModel>(
          path: '/api/posts/all',
          model: const DummyModel(),
          method: RequestMethod.get,
        ),
        netKitManager.requestModel<DummyModel>(
          path: '/api/posts/likes',
          model: const DummyModel(),
          method: RequestMethod.get,
        ),
        netKitManager.requestModel<DummyModel>(
          path: '/api/messages/all',
          model: const DummyModel(),
          method: RequestMethod.get,
        ),
      ];

      // Run all in parallel
      final results = await Future.wait(requests);

      // All results should be DummyModel
      for (final res in results) {
        expect(res, isA<DummyModel>());
      }
      // Only one refresh call should have happened
      expect(backendState.refreshCallCount, 1);
      // Storage should be updated with the latest tokens
      expect(await authStorage.getAccessToken(), backendState.accessToken);
      expect(await authStorage.getRefreshToken(), backendState.refreshToken);
    });

    //Single refresh, refresh token already used (should fail on second try)
    test('Second refresh attempt with already used refresh token fails',
        () async {
      // 1. Set expired access, current refresh.
      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      // 2. Do a call that causes refresh (should succeed).
      final result = await netKitManager.requestModel<DummyModel>(
        path: '/api/user/current',
        model: const DummyModel(),
        method: RequestMethod.get,
      );
      expect(result, isA<DummyModel>());
      expect(backendState.refreshCallCount, 1);

      // 3. Manually roll back to the *old*
      // refresh token (simulate replay attack).
      await authStorage.setRefreshToken('REFRESH_1');
      netKitManager
        ..setRefreshToken('REFRESH_1')

        // 4. Expire access token again, attempt another request.
        ..setAccessToken('EXPIRED_ACCESS_TOKEN');
      try {
        await netKitManager.requestModel<DummyModel>(
          path: '/api/posts/all',
          model: const DummyModel(),
          method: RequestMethod.get,
        );
        fail('Should have failed: refresh token is already used');
      } on ApiException catch (e) {
        expect(e.message, contains('invalid or already used'));
      }
    });

    // All refresh tokens exhausted (simulate user logout
    // everywhere, should fail all requests)
    test('All tokens revoked: refresh fails, user must re-login', () async {
      // Simulate backend revoking all tokens
      backendState.usedRefreshTokens.add(backendState.refreshToken);

      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      try {
        await netKitManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        );
        fail('Should fail: refresh token revoked');
      } on ApiException catch (e) {
        expect(e.message, contains('invalid or already used'));
      }
    });

    // Refresh token is missing (should fail fast)
    test('No refresh token in storage, refresh fails immediately', () async {
      // Clear refresh token
      await authStorage.setRefreshToken(null);

      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(null);

      try {
        await netKitManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        );
        fail('Should fail: no refresh token');
      } on ApiException catch (e) {
        expect(e.message, contains('required'));
      }
    });

    test('Refresh response missing access token triggers onRefreshFailed',
        () async {
      backendState.returnRefreshWithoutAccessToken = true;
      var refreshFailedCalled = false;

      final manager = NetKitManager(
        baseUrl: baseUrl.toString(),
        refreshTokenPath: '/api/refresh',
        dataKey: 'data',
        internetStatusStream: Stream.value(true),
        onRefreshFailed: ({
          required int? statusCode,
          required DioException exception,
        }) {
          refreshFailedCalled = true;
        },
      )
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      try {
        await manager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        );
        fail('Should fail: refresh response missing access token');
      } on ApiException catch (e) {
        expect(refreshFailedCalled, isTrue);
        expect(
          e.message,
          contains('Could not parse tokens from refresh response'),
        );
      }

      manager.dispose();
      backendState.returnRefreshWithoutAccessToken = false;
    });

    // Simulate delayed backend refresh to stress-test queuing
    test('Delayed refresh: all queued requests are retried after refresh',
        () async {
      // Add artificial delay in backend
      backendState.refreshDelayMs = 800;

      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      final start = DateTime.now();

      final requests = [
        netKitManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        ),
        netKitManager.requestModel<DummyModel>(
          path: '/api/posts/all',
          model: const DummyModel(),
          method: RequestMethod.get,
        ),
        netKitManager.requestModel<DummyModel>(
          path: '/api/posts/likes',
          model: const DummyModel(),
          method: RequestMethod.get,
        ),
        netKitManager.requestModel<DummyModel>(
          path: '/api/messages/all',
          model: const DummyModel(),
          method: RequestMethod.get,
        ),
      ];

      final results = await Future.wait(requests);
      final elapsed = DateTime.now().difference(start).inMilliseconds;

      expect(results.length, 4);
      for (final r in results) {
        expect(r, isA<DummyModel>());
      }
      expect(backendState.refreshCallCount, 1);
      // Ensures refresh delay is observed
      expect(elapsed, greaterThanOrEqualTo(800));

      // Reset backend delay for other tests
      backendState.refreshDelayMs = 0;
    });

    // Mix of valid and expired tokens (one triggers refresh, others succeed)
    test(
        'First expired triggers refresh, '
        'second uses new token (no extra refresh)', () async {
      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      // First call triggers refresh
      final first = await netKitManager.requestModel<DummyModel>(
        path: '/api/user/current',
        model: const DummyModel(),
        method: RequestMethod.get,
      );
      expect(first, isA<DummyModel>());
      expect(backendState.refreshCallCount, 1);

      // Second call (with new tokens) does not trigger refresh
      netKitManager.setAccessToken(backendState.accessToken);
      final second = await netKitManager.requestModel<DummyModel>(
        path: '/api/posts/likes',
        model: const DummyModel(),
        method: RequestMethod.get,
      );
      expect(second, isA<DummyModel>());
      expect(backendState.refreshCallCount, 1);
    });

    test('Logout: tokens cleared, refresh fails', () async {
      // Simulate logout by clearing both tokens in storage
      await authStorage.setAccessToken(null);
      await authStorage.setRefreshToken(null);

      netKitManager
        ..setAccessToken(null)
        ..setRefreshToken(null);

      try {
        await netKitManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        );
        fail('Should fail: no refresh token after logout');
      } on ApiException catch (e) {
        expect(
          e.message,
          contains(
            'required',
          ),
        ); // Or whatever your backend returns for missing token
      }
    });
    test('Access token revoked on backend: triggers refresh, then succeeds',
        () async {
      // 1. Start with valid tokens
      netKitManager
        ..setAccessToken(backendState.accessToken)
        ..setRefreshToken(backendState.refreshToken);

      // 2. Simulate backend revoking the current access token
      backendState.revokedAccessTokens
          .add('Bearer ${backendState.accessToken}');

      // 3. Request should get 401, trigger refresh, and then succeed
      final result = await netKitManager.requestModel<DummyModel>(
        path: '/api/user/current',
        model: const DummyModel(),
        method: RequestMethod.get,
      );

      expect(result, isA<DummyModel>());
      expect(backendState.refreshCallCount, 1);
      // Ensure token rotation happened
      expect(await authStorage.getAccessToken(), backendState.accessToken);
    });

    test('Fuzz: Multiple parallel requests, random refresh delay', () async {
      // Give backend a random delay (up to 500ms) for refresh
      backendState.refreshDelayMs = Random().nextInt(500);

      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      final calls = [
        netKitManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        ),
        netKitManager.requestModel<DummyModel>(
          path: '/api/posts/all',
          model: const DummyModel(),
          method: RequestMethod.get,
        ),
        netKitManager.requestModel<DummyModel>(
          path: '/api/posts/likes',
          model: const DummyModel(),
          method: RequestMethod.get,
        ),
        netKitManager.requestModel<DummyModel>(
          path: '/api/messages/all',
          model: const DummyModel(),
          method: RequestMethod.get,
        ),
      ];

      final results = await Future.wait(calls);
      for (final r in results) {
        expect(r, isA<DummyModel>());
      }
      expect(backendState.refreshCallCount, 1);
    });

    test('App killed/restarted: NetKit loads token from storage and refreshes',
        () async {
      // 1. Start with valid tokens in storage
      await authStorage.setAccessToken(backendState.accessToken);
      await authStorage.setRefreshToken(backendState.refreshToken);

      // 2. Create a new NetKitManager (simulate app restart)
      netKitManager = createNetKitManagerWithStorage(authStorage)
        // 3. Invalidate access token (simulate expired)
        ..setAccessToken('EXPIRED_ACCESS_TOKEN');
      try {
        // 4. Request triggers refresh
        final user = await netKitManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        );

        expect(user, isA<DummyModel>());
        expect(backendState.refreshCallCount, 1);
      } on ApiException catch (e) {
        fail('Request failed with error: ${e.message}');
      }
    });

    test('Network flakiness during refresh: should handle failure gracefully',
        () async {
      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      backendState.simulateRefreshFailure = true;

      try {
        await netKitManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        );
        fail('Should have thrown due to refresh network failure');
      } on ApiException catch (e) {
        expect(e.message, contains('Simulated network error'));
        expect(e.statusCode, 500);
      } finally {
        backendState.simulateRefreshFailure = false;
      }
    });

    test('Fuzz: Repeat refresh race with changing tokens', () async {
      for (var i = 0; i < 10; i++) {
        backendState.reset();
        netKitManager
          ..setAccessToken('EXPIRED_ACCESS_TOKEN')
          ..setRefreshToken(backendState.refreshToken);

        // Simulate random delay for backend refresh
        backendState.refreshDelayMs = Random().nextInt(200);

        final calls = [
          netKitManager.requestModel<DummyModel>(
            path: '/api/user/current',
            model: const DummyModel(),
            method: RequestMethod.get,
          ),
          netKitManager.requestModel<DummyModel>(
            path: '/api/posts/all',
            model: const DummyModel(),
            method: RequestMethod.get,
          ),
        ];

        final results = await Future.wait(calls);
        for (final r in results) {
          expect(r, isA<DummyModel>());
        }
        // After refresh, tokens are rotated!
        expect(backendState.refreshCallCount, 1);
        expect(await authStorage.getAccessToken(), backendState.accessToken);
        expect(await authStorage.getRefreshToken(), backendState.refreshToken);
      }
    });

    test('Network flakiness during refresh: should handle failure gracefully',
        () async {
      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      backendState.simulateRefreshFailure = true;

      try {
        await netKitManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        );
        fail('Should have thrown due to refresh network failure');
      } on ApiException catch (e) {
        expect(e.message, contains('Simulated network error'));
      } finally {
        backendState.simulateRefreshFailure = false;
      }
    });

    test('Offline refresh skips HTTP attempt and triggers onRefreshFailed',
        () async {
      var refreshFailedCalled = false;
      final connectivityController = StreamController<bool>.broadcast();
      final offlineManager = NetKitManager(
        baseUrl: baseUrl.toString(),
        refreshTokenPath: '/api/refresh',
        dataKey: 'data',
        internetStatusStream: connectivityController.stream,
        onBeforeRefreshRequest: (_) {
          connectivityController.add(false);
        },
        onRefreshFailed: ({
          required int? statusCode,
          required DioException exception,
        }) {
          refreshFailedCalled = true;
        },
      );

      connectivityController.add(true);
      await Future<void>.delayed(Duration.zero);

      offlineManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      try {
        await offlineManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        );
        fail('Expected request to fail while offline during refresh');
      } on ApiException catch (e) {
        expect(e.message, 'No internet connection');
      }

      expect(refreshFailedCalled, isTrue);
      expect(backendState.refreshCallCount, 0);
      await connectivityController.close();
      offlineManager.dispose();
    });

    test('Retried request fails when retry response is non-2xx', () async {
      backendState.failRetriedRequestsAfterRefresh = true;

      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      try {
        await netKitManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        );
        fail('Expected request to fail after retry returned 500');
      } on ApiException catch (e) {
        expect(e.statusCode, 500);
      }

      expect(backendState.refreshCallCount, 1);
      expect(backendState.protectedCallCount, 2);
    });

    test(
      'Offline from stream fails before refresh HTTP is attempted',
      () async {
      final offlineManager = NetKitManager(
        baseUrl: baseUrl.toString(),
        refreshTokenPath: '/api/refresh',
        dataKey: 'data',
        internetStatusStream: Stream.value(false),
      );

      await Future<void>.delayed(Duration.zero);

      offlineManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      try {
        await offlineManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        );
        fail('Expected offline request to fail');
      } on ApiException catch (e) {
        expect(e.message, 'No internet connection');
      }

      expect(backendState.refreshCallCount, 0);
      offlineManager.dispose();
    });

    test('Refresh succeeds when removeAccessTokenBeforeRefresh is false',
        () async {
      final manager = NetKitManager(
        baseUrl: baseUrl.toString(),
        refreshTokenPath: '/api/refresh',
        dataKey: 'data',
        removeAccessTokenBeforeRefresh: false,
        internetStatusStream: Stream.value(true),
        onTokenRefreshed: (token) async {
          await authStorage.setAccessToken(token.accessToken);
          if (token.refreshToken != null) {
            await authStorage.setRefreshToken(token.refreshToken);
          }
        },
      )
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      final result = await manager.requestModel<DummyModel>(
        path: '/api/user/current',
        model: const DummyModel(),
        method: RequestMethod.get,
      );

      expect(result, isA<DummyModel>());
      expect(backendState.refreshCallCount, 1);
      expect(backendState.protectedCallCount, 2);
      expect(await authStorage.getAccessToken(), backendState.accessToken);
      manager.dispose();
    });

    test('Retried request succeeds after token refresh', () async {
      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      final result = await netKitManager.requestModel<DummyModel>(
        path: '/api/user/current',
        model: const DummyModel(),
        method: RequestMethod.get,
      );

      expect(result, isA<DummyModel>());
      expect(backendState.refreshCallCount, 1);
      expect(backendState.protectedCallCount, 2);
    });

    test('403 on protected route does not trigger refresh', () async {
      netKitManager
        ..setAccessToken(backendState.accessToken)
        ..setRefreshToken(backendState.refreshToken);

      try {
        await netKitManager.requestModel<DummyModel>(
          path: '/api/forbidden',
          model: const DummyModel(),
          method: RequestMethod.get,
        );
        fail('Expected 403');
      } on ApiException catch (e) {
        expect(e.statusCode, 403);
      }

      expect(backendState.refreshCallCount, 0);
    });

    test('skipTokenRefresh skips automatic refresh on 401', () async {
      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      try {
        await netKitManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
          skipTokenRefresh: true,
        );
        fail('Expected 401');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
      }

      expect(backendState.refreshCallCount, 0);
    });

    test('POST 401 refreshes but does not replay without allowRetryOn401',
        () async {
      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      try {
        await netKitManager.requestVoid(
          path: '/api/posts/create',
          method: RequestMethod.post,
          body: {'title': 'test'},
        );
        fail('Expected non-idempotent retry block');
      } on ApiException catch (e) {
        expect(
          e.message,
          const NetKitErrorParams().nonIdempotentRetryBlockedError,
        );
      }

      expect(backendState.refreshCallCount, 1);
      expect(backendState.protectedCallCount, 1);
    });

    test('POST with allowRetryOn401 replays once after refresh', () async {
      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      await netKitManager.requestVoid(
        path: '/api/posts/create',
        method: RequestMethod.post,
        body: {'title': 'test'},
        allowRetryOn401: true,
      );

      expect(backendState.refreshCallCount, 1);
      expect(backendState.protectedCallCount, 2);
    });

    test('requestVoid accepts 204 No Content', () async {
      await netKitManager.requestVoid(
        path: '/api/items/1',
        method: RequestMethod.delete,
      );
    });

    test('requestModel with 204 throws emptyResponseBodyError', () async {
      try {
        await netKitManager.requestModel<DummyModel>(
          path: '/api/items/empty',
          model: const DummyModel(),
          method: RequestMethod.get,
        );
        fail('Expected empty body error');
      } on ApiException catch (e) {
        expect(
          e.message,
          const NetKitErrorParams().emptyResponseBodyError,
        );
      }
    });

    test('50+ concurrent 401s trigger exactly one refresh', () async {
      backendState.refreshDelayMs = 100;
      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      final futures = List.generate(
        55,
        (_) => netKitManager.requestModel<DummyModel>(
          path: '/api/user/current',
          model: const DummyModel(),
          method: RequestMethod.get,
        ),
      );

      final results = await Future.wait(futures);
      for (final result in results) {
        expect(result, isA<DummyModel>());
      }
      expect(backendState.refreshCallCount, 1);
    });

    test('cancelToken cancelled during refresh yields cancel', () async {
      backendState.refreshDelayMs = 500;
      netKitManager
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      final cancelToken = CancelToken();
      final future = netKitManager.requestModel<DummyModel>(
        path: '/api/user/current',
        model: const DummyModel(),
        method: RequestMethod.get,
        cancelToken: cancelToken,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      cancelToken.cancel('cancelled before retry');

      try {
        await future;
        fail('Expected cancel');
      } on ApiException catch (e) {
        expect(e.message, contains('cancelled'));
      }
    });

    test('formUrlEncoded refresh succeeds', () async {
      final formManager = NetKitManager(
        baseUrl: baseUrl.toString(),
        refreshTokenPath: '/api/refresh',
        dataKey: 'data',
        refreshTokenContentType: RefreshTokenContentType.formUrlEncoded,
        internetStatusStream: Stream.value(true),
        onTokenRefreshed: (token) async {
          await authStorage.setAccessToken(token.accessToken);
          if (token.refreshToken != null) {
            await authStorage.setRefreshToken(token.refreshToken);
          }
        },
      )
        ..setAccessToken('EXPIRED_ACCESS_TOKEN')
        ..setRefreshToken(backendState.refreshToken);

      final result = await formManager.requestModel<DummyModel>(
        path: '/api/user/current',
        model: const DummyModel(),
        method: RequestMethod.get,
      );

      expect(result, isA<DummyModel>());
      expect(backendState.refreshCallCount, 1);
      formManager.dispose();
    });
  });
}
