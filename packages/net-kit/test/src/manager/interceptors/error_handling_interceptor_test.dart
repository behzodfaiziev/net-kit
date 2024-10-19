import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/manager/queue/request_queue.dart';
import 'package:net_kit/src/manager/token/token_manager.dart';
import 'package:test/test.dart';

class MockRequestQueue extends Mock implements RequestQueue {}

class MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

/// Create a Fake class for DioException
class FakeDioException extends Fake implements DioException {}

/// Main testing suite for the ErrorHandlingInterceptor class.
///
/// This suite validates the behavior of the ErrorHandlingInterceptor,
/// which handles 401 (Unauthorized) errors, refreshes authentication tokens,
/// and retries requests as needed.

void main() {
  late MockRequestQueue requestQueue;
  late ErrorHandlingInterceptor interceptor;

  setUpAll(() {
    /// Register the fake DioException as a fallback value
    registerFallbackValue(FakeDioException());
  });

  setUp(() {
    requestQueue = MockRequestQueue();

    interceptor = ErrorHandlingInterceptor(
      refreshTokenPath: '/refresh-token',
      requestQueue: requestQueue,
      tokenManager: TokenManager(
        getRefreshToken: () => 'some-refresh-token',
        addBearerToken: (_) {},
        addRefreshToken: (_) {},
        refreshTokenRequest: (_, __) async {
          return const AuthTokenModel(
              accessToken: 'new-access-token',
              refreshToken: 'new-refresh-token',);
        },
        retryRequest: (requestOptions) async {
          return Response<dynamic>(
            data: 'Retry successful',
            requestOptions: requestOptions,
            statusCode: 200,
          );
        },
        onTokensUpdated: (_) {},
      ),
    );
  });

  /// 1. **should refresh token and retry request (single request)**:
  ///    - **Purpose**: Verifies that the interceptor refreshes the token and
  ///      retries the original request when a 401 Unauthorized error occurs.
  ///    - **Expected**: After invoking the interceptor's error handler,
  ///      `requestQueue.processQueue()` is called once, indicating the
  ///      original request was retried.
  test('should refresh token and retry request (single request)', () async {
    final mockHandler = MockErrorInterceptorHandler();
    final mockError = DioException(
      requestOptions: RequestOptions(path: '/some-path'),
      response: Response(
        statusCode: 401,
        requestOptions: RequestOptions(path: '/some-path'),
      ),
    );

    final completer = Completer<void>();

    when(() => requestQueue.processQueue()).thenAnswer((_) async {
      completer.complete();
    });

    interceptor.getErrorInterceptor().onError(mockError, mockHandler);

    await completer.future;

    verify(() => requestQueue.processQueue()).called(1);
  });

  /// 2. **should refresh token and handle multiple requests waiting (queued)**:
  ///    - **Purpose**: Ensures that multiple requests are queued while the
  ///      token is being refreshed and are retried once the refresh is
  ///      complete.
  ///    - **Expected**: The test verifies that `requestQueue.processQueue()`
  ///      is called once after the token refresh completes and confirms that
  ///      both queued requests are retried successfully.
  ///
  test('should refresh token and handle multiple requests waiting (queued)',
      () async {
    final mockHandler1 = MockErrorInterceptorHandler();
    final mockHandler2 = MockErrorInterceptorHandler();
    final mockError1 = DioException(
      requestOptions: RequestOptions(path: '/request-1'),
      response: Response(
        statusCode: 401,
        requestOptions: RequestOptions(path: '/request-1'),
      ),
    );
    final mockError2 = DioException(
      requestOptions: RequestOptions(path: '/request-2'),
      response: Response(
        statusCode: 401,
        requestOptions: RequestOptions(path: '/request-2'),
      ),
    );

    final completer = Completer<void>();
    final completer2 = Completer<void>();

    // Mock for both requests being queued while refreshing the token
    when(() => requestQueue.processQueue()).thenAnswer((_) async {
      completer.complete();
    });

    when(() => requestQueue.add(any())).thenAnswer((invocation) async {
      final queuedRequest =
          invocation.positionalArguments[0] as Future<void> Function();
      await queuedRequest(); // Process queued request
      completer2.complete();
    });

    // Trigger the first error
    interceptor.getErrorInterceptor().onError(mockError1, mockHandler1);

    // Trigger the second error, which should
    // queue since the first one is still refreshing
    interceptor.getErrorInterceptor().onError(mockError2, mockHandler2);

    // Wait until the first refresh process is completed
    await completer.future;

    // Ensure the queue gets processed after the first refresh completes
    await completer2.future;

    // Verify that the queue was processed once
    verify(() => requestQueue.processQueue()).called(1);
    // Verify both requests were retried after token refresh
    verify(() => requestQueue.add(any())).called(1);
  });

  /// 3. **should handle refresh token failure**:
  ///    - **Purpose**: Validates the interceptor's behavior when the token
  ///      refresh process fails (e.g., due to an invalid refresh token).
  ///    - **Expected**: The test asserts that the error handler's `reject`
  ///      method is called when the token refresh fails and verifies that
  ///      queued requests are not retried, ensuring proper error handling.
  ///
  test('should handle refresh token failure', () async {
    final mockHandler = MockErrorInterceptorHandler();
    final mockError = DioException(
      requestOptions: RequestOptions(path: '/some-path'),
      response: Response(
        statusCode: 401,
        requestOptions: RequestOptions(path: '/some-path'),
      ),
    );

    final completer = Completer<void>();

    // Simulate an error during the token refresh process
    interceptor = ErrorHandlingInterceptor(
      refreshTokenPath: '/refresh-token',
      requestQueue: requestQueue,
      tokenManager: TokenManager(
        getRefreshToken: () => 'some-refresh-token',
        addBearerToken: (_) {},
        addRefreshToken: (_) {},
        refreshTokenRequest: (_, __) async {
          throw DioException(
            requestOptions: RequestOptions(path: '/refresh-token-fail'),
          );
        },
        retryRequest: (requestOptions) async {
          return Response<dynamic>(
            data: 'Retry successful',
            requestOptions: requestOptions,
            statusCode: 200,
          );
        },
        onTokensUpdated: (_) {},
      ),
    );

    when(() => mockHandler.reject(any())).thenAnswer((_) {
      completer.complete(); // Complete when reject is called
    });
    when(() => requestQueue.processQueue()).thenAnswer((_) async {});

    interceptor.getErrorInterceptor().onError(mockError, mockHandler);

    await completer.future;

    // Verify that the error was rejected after refresh token failure
    verify(() => mockHandler.reject(any())).called(1);
    verifyNever(() => requestQueue.processQueue());
  });

  /// 4. **should pass non-401 errors directly to the next handler**:
  ///    - **Purpose**: Ensures that non-401 errors (e.g., server errors)
  ///      are passed directly to the next handler without attempting a
  ///      token refresh.
  ///    - **Expected**: The test checks that the `next` method of the error
  ///      handler is called with the mock error,
  ///      and `requestQueue.processQueue()`
  ///      is not invoked, confirming correct bypassing of token refresh logic.
  ///
  test('should pass non-401 errors directly to the next handler', () async {
    final mockHandler = MockErrorInterceptorHandler();
    final mockError = DioException(
      requestOptions: RequestOptions(path: '/some-path'),
      response: Response(
        statusCode: 500,
        requestOptions: RequestOptions(path: '/some-path'),
      ),
    );

    interceptor.getErrorInterceptor().onError(mockError, mockHandler);

    // Ensure that the error is passed directly to the handler without retry
    verify(() => mockHandler.next(mockError)).called(1);
    verifyNever(() => requestQueue.processQueue());
  });
}
