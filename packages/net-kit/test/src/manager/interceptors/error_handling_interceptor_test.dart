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
  final mockHandler = MockErrorInterceptorHandler();

  final invalidRefreshTokenException = DioException(
    requestOptions: RequestOptions(path: '/refresh-token'),
    response: Response(
      statusCode: 401,
      requestOptions: RequestOptions(path: '/refresh-token'),
    ),
  );
  final unauthorizedException = DioException(
    requestOptions: RequestOptions(path: '/some-path'),
    response: Response(
      statusCode: 401,
      requestOptions: RequestOptions(path: '/some-path'),
    ),
  );
  final unauthorizedException2 = DioException(
    requestOptions: RequestOptions(path: '/some-path=2'),
    response: Response(
      statusCode: 401,
      requestOptions: RequestOptions(path: '/some-path=2'),
    ),
  );
  const authTokenModel = AuthTokenModel(
    accessToken: 'new-access-token',
    refreshToken: 'new-refresh-token',
  );

  final internalServerException = DioException(
    requestOptions: RequestOptions(path: '/some-path'),
    response: Response(
      statusCode: 500,
      requestOptions: RequestOptions(path: '/some-path'),
    ),
  );
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
          return authTokenModel;
        },
        retryRequest: (requestOptions) async {
          return successfulRetryResponse(requestOptions);
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
    final completer = Completer<void>();

    when(() => requestQueue.processQueue())
        .thenAnswer((_) async => completer.complete());

    interceptor
        .getErrorInterceptor()
        .onError(unauthorizedException, mockHandler);

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
    final mockHandler2 = MockErrorInterceptorHandler();

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
    interceptor
        .getErrorInterceptor()
        .onError(unauthorizedException, mockHandler);

// Trigger the second error, which should
// queue since the first one is still refreshing
    interceptor
        .getErrorInterceptor()
        .onError(unauthorizedException2, mockHandler2);

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
          throw invalidRefreshTokenException;
        },
        retryRequest: (requestOptions) async {
          return successfulRetryResponse(requestOptions);
        },
        onTokensUpdated: (_) {},
      ),
    );

    when(() => mockHandler.reject(any())).thenAnswer((_) {
      completer.complete(); // Complete when reject is called
    });
    when(() => requestQueue.processQueue()).thenAnswer((_) async {});

    interceptor
        .getErrorInterceptor()
        .onError(unauthorizedException, mockHandler);

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
    interceptor
        .getErrorInterceptor()
        .onError(internalServerException, mockHandler);

// Ensure that the error is passed directly to the handler without retry
    verify(() => mockHandler.next(internalServerException)).called(1);
    verifyNever(() => requestQueue.processQueue());
  });

  /// 5. **should reject if refresh token request returns 401**:
  ///    - **Purpose**: Validates the interceptor's behavior when the refresh
  ///      token request itself fails with a 401 error, indicating the refresh
  ///      token has expired.
  ///    - **Expected**: The test asserts that the error handler's `reject`
  ///      method is called with a specific error message, and queued requests
  ///      are rejected, confirming proper handling of the expired
  ///      refresh token.
  test('should reject if refresh token request returns 401', () async {
    // Set up a completer to track when the reject method is called
    final completer = Completer<void>();

    // Mock the reject method to complete the completer
    when(() => mockHandler.reject(any())).thenAnswer((_) {
      completer.complete();
    });

    // Invoke the interceptor with the 401 error from the refresh token request
    interceptor
        .getErrorInterceptor()
        .onError(invalidRefreshTokenException, mockHandler);

    // Wait until the completer is completed
    await completer.future;

    // Capture the argument passed to the reject method
    final capturedException = verify(() => mockHandler.reject(captureAny()))
        .captured
        .single as DioException;

// Verify that the captured exception has the expected properties
    expect(capturedException.requestOptions.path, '/refresh-token');

// Verify that queued requests are rejected
    verify(() => requestQueue.rejectQueuedRequests()).called(1);
  });
  test(
      'should throw DioException with correct message '
      'and status code on error in when refreshTokenRequest fails', () async {
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
          throw invalidRefreshTokenException;
        },
        retryRequest: (requestOptions) async {
          return successfulRetryResponse(requestOptions);
        },
        onTokensUpdated: (_) {},
      ),
    );

    when(() => mockHandler.reject(any())).thenAnswer((_) {
      completer.complete(); // Complete when reject is called
    });
    when(() => requestQueue.rejectQueuedRequests()).thenAnswer((_) async {});

    interceptor
        .getErrorInterceptor()
        .onError(unauthorizedException, mockHandler);

    await completer.future;

// Verify that the error was rejected after refresh token failure
    final capturedException = verify(() => mockHandler.reject(captureAny()))
        .captured
        .single as DioException;

    expect(capturedException.requestOptions.path, '/refresh-token');
    expect(capturedException.response?.statusCode, 401);
    verifyNever(() => requestQueue.processQueue());
    verify(() => requestQueue.rejectQueuedRequests()).called(1);
  });

  test(
    'should throw DioException with correct message '
    'and status code on error in when refreshTokenRequest fails.',
    () async {
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
            return authTokenModel;
          },
          retryRequest: (requestOptions) async {
            throw internalServerException;
          },
          onTokensUpdated: (_) {},
        ),
      );

      when(() => mockHandler.reject(any())).thenAnswer((_) {
        completer.complete(); // Complete when reject is called
      });
      when(() => requestQueue.rejectQueuedRequests()).thenAnswer((_) async {});

      interceptor
          .getErrorInterceptor()
          .onError(unauthorizedException, mockHandler);

      await completer.future;

// Verify that the error was rejected after refresh token failure
      final capturedException = verify(() => mockHandler.reject(captureAny()))
          .captured
          .single as DioException;

      expect(
        capturedException.requestOptions.path,
        internalServerException.requestOptions.path,
      );
      expect(
        capturedException.response?.statusCode,
        internalServerException.response?.statusCode,
      );
      verifyNever(() => requestQueue.processQueue());
      verify(() => requestQueue.rejectQueuedRequests()).called(1);
    },
  );
}

Response<dynamic> successfulRetryResponse(RequestOptions requestOptions) {
  return Response<dynamic>(
    data: 'Retry successful',
    requestOptions: requestOptions,
    statusCode: 200,
  );
}
