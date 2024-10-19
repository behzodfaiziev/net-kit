import 'package:mocktail/mocktail.dart';
import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/manager/interceptors/error_interceptor.dart';
import 'package:net_kit/src/manager/queue/request_queue.dart';
import 'package:test/test.dart';

import '../../../mocks/mock_error_interceptor_handler.dart';
import '../../../mocks/mock_http_client_adapter.dart';
import '../../../mocks/mock_net_kit_manager.dart';

void main() {
  late NetKitManager netKitManager;
  late MockHttpClientAdapter clientAdapter;
  final unauthorizedException = DioException(
    requestOptions: RequestOptions(path: '/some-path'),
    response: Response(
      statusCode: 401,
      requestOptions: RequestOptions(path: '/some-path'),
    ),
  );

  setUpAll(() {
    registerFallbackValue(RequestMethod.get);
    registerFallbackValue(unauthorizedException);
    registerFallbackValue(MockErrorInterceptorHandler());
    registerFallbackValue('refreshToken');
    registerFallbackValue(Options());
  });
  setUp(() {
    clientAdapter = MockHttpClientAdapter();
    netKitManager = MockNetKitManager();
    final handler = ErrorHandlingInterceptor(
      refreshTokenPath: '/refresh-token',
      requestQueue: RequestQueue(),
      netKitManager: netKitManager,
    );

    final interceptors = Interceptors()..add(handler.getErrorInterceptor());

    when(() => netKitManager.interceptors).thenReturn(interceptors);
  });

  test('should successfully refresh token and retry request', () async {
    when(() => netKitManager.getRefreshToken()).thenReturn('refreshToken');

    when(
      () => netKitManager.requestVoid(
        path: any(named: 'path'),
        method: any(named: 'method'),
        options: any(named: 'options'),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(unauthorizedException);

    when(
      () => netKitManager.request<dynamic>(
        '/refresh-token',
        options: any(named: 'options'),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response(
        data: {
          'accessToken': 'newAccessToken',
          'refreshToken': 'newRefreshToken',
        },
        requestOptions: RequestOptions(path: '/refresh-token'),
        statusCode: 200,
      ),
    );

    when(
      () => netKitManager.request<dynamic>(
        '/some-path',
        options: any(named: 'options'),
        data: any(named: 'data'),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response(
        data: 'Success',
        statusCode: 200,
        requestOptions: RequestOptions(path: '/some-path'),
      ),
    );

    try {
      final interceptors = netKitManager.interceptors;

      final result = netKitManager.requestVoid(
        path: '/some-path',
        method: RequestMethod.get,
      );
    } catch (e) {
      print(e);
    }

    final interceptorsWrapper = netKitManager.interceptors.firstWhere(
      (interceptor) => interceptor is ErrorInterceptor,
    ) as ErrorInterceptor;

    // Verify that onError is called
    verify(() => interceptorsWrapper.onError(any(), any())).called(1);
    verify(() => netKitManager.getRefreshToken()).called(1);

    //
    // verify(
    //   () => netKitManager.request<dynamic>(
    //     '/refresh-token',
    //     options: any(named: 'options'),
    //     data: any(named: 'data'),
    //     queryParameters: any(named: 'queryParameters'),
    //   ),
    // ).called(1);

    // verify(
    //   () => netKitManager.request<dynamic>(
    //     '/some-path',
    //     options: any(named: 'options'),
    //     data: any(named: 'data'),
    //     queryParameters: any(named: 'queryParameters'),
    //   ),
    // ).called(1);

    // verify(() => handler.resolve(any())).called(1);
  });

  // test('should queue requests while token is refreshing', () async {
  //   final errorResponse = DioException(
  //     requestOptions: RequestOptions(path: '/some-path'),
  //     response: Response(
  //       statusCode: 401,
  //       requestOptions: RequestOptions(path: '/some-path'),
  //     ),
  //   );
  //
  //   when(
  //     () => netKitManager.request<dynamic>(
  //       '/some-path',
  //       options: any(named: 'options'),
  //       data: any(named: 'data'),
  //       queryParameters: any(named: 'queryParameters'),
  //     ),
  //   ).thenThrow(errorResponse);
  //
  //   when(
  //     () => netKitManager.request<dynamic>(
  //       '/refresh-token',
  //       options: any(named: 'options'),
  //       data: any(named: 'data'),
  //       queryParameters: any(named: 'queryParameters'),
  //     ),
  //   ).thenAnswer((_) async {
  //     await Future<void>.delayed(const Duration(seconds: 1));
  //     return Response(
  //       data: {
  //         'accessToken': 'newAccessToken',
  //         'refreshToken': 'newRefreshToken',
  //       },
  //       statusCode: 200,
  //       requestOptions: RequestOptions(path: '/refresh-token'),
  //     );
  //   });
  //
  //   final handler1 = MockErrorInterceptorHandler();
  //   final handler2 = MockErrorInterceptorHandler();
  //
  //   final interceptorsWrapper = netKitManager.interceptors.firstWhere(
  //     (interceptor) => interceptor is ErrorInterceptor,
  //   ) as ErrorInterceptor;
  //
  //   interceptorsWrapper.onError(errorResponse, handler1);
  //   interceptorsWrapper.onError(errorResponse, handler2);
  //
  //   await Future<void>.delayed(const Duration(seconds: 2));
  //
  //   verify(() => handler1.resolve(any())).called(1);
  //   verify(() => handler2.resolve(any())).called(1);
  // });
  //
  // test('should return error if token refresh fails', () async {
  //   final errorResponse = DioException(
  //     requestOptions: RequestOptions(path: '/some-path'),
  //     response: Response(
  //       statusCode: 401,
  //       requestOptions: RequestOptions(path: '/some-path'),
  //     ),
  //   );
  //
  //   when(
  //     () => netKitManager.request<dynamic>(
  //       '/some-path',
  //       options: any(named: 'options'),
  //       data: any(named: 'data'),
  //       queryParameters: any(named: 'queryParameters'),
  //     ),
  //   ).thenThrow(errorResponse);
  //
  //   when(
  //     () => netKitManager.request<dynamic>(
  //       '/refresh-token',
  //       options: any(named: 'options'),
  //       data: any(named: 'data'),
  //       queryParameters: any(named: 'queryParameters'),
  //     ),
  //   ).thenThrow(Exception('Token refresh failed'));
  //
  //   final handler = MockErrorInterceptorHandler();
  //
  //   final interceptorsWrapper = netKitManager.interceptors.firstWhere(
  //     (interceptor) => interceptor is ErrorInterceptor,
  //   ) as ErrorInterceptor;
  //
  //   interceptorsWrapper.onError(errorResponse, handler);
  //
  //   verify(() => handler.reject(any())).called(1);
  // });
}
