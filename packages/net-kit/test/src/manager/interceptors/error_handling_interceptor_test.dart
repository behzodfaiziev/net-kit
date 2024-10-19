import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/manager/queue/request_queue.dart';
import 'package:test/test.dart';


class MockRequestQueue extends Mock implements RequestQueue {}

class MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

/// Create a Fake class for DioException
class FakeDioException extends Fake implements DioException {}

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
      getRefreshToken: () => 'some-refresh-token',
      addBearerToken: (_) {},
      addRefreshToken: (_) {},
      refreshTokenRequest: (_, __) async {
        return const AuthTokenModel(
            accessToken: 'new-access-token', refreshToken: 'new-refresh-token');
      },
      retryRequest: (requestOptions) async {
        return Response<dynamic>(
          data: 'Retry successful',
          requestOptions: requestOptions,
          statusCode: 200,
        );
      },
      onTokensUpdated: (_) {},
    );
  });

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

  test('should refresh token and handle multiple requests waiting (queued)', () async {
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
      final queuedRequest = invocation.positionalArguments[0] as Future<void> Function();
      await queuedRequest(); // Process queued request
      completer2.complete();
    });

    // Trigger the first error
    interceptor.getErrorInterceptor().onError(mockError1, mockHandler1);

    // Trigger the second error, which should queue since the first one is still refreshing
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
      getRefreshToken: () => 'some-refresh-token',
      addBearerToken: (_) {},
      addRefreshToken: (_) {},
      refreshTokenRequest: (_, __) async {
        throw DioException(requestOptions: RequestOptions(path: '/refresh-token-fail'));
      },
      retryRequest: (requestOptions) async {
        return Response<dynamic>(
          data: 'Retry successful',
          requestOptions: requestOptions,
          statusCode: 200,
        );
      },
      onTokensUpdated: (_) {},
    );

    when(() => mockHandler.reject(any())).thenAnswer((_) {
      completer.complete(); // Complete when reject is called
    });

    interceptor.getErrorInterceptor().onError(mockError, mockHandler);

    await completer.future;

    // Verify that the error was rejected after refresh token failure
    verify(() => mockHandler.reject(any())).called(1);
    verifyNever(() => requestQueue.processQueue());
  });

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
