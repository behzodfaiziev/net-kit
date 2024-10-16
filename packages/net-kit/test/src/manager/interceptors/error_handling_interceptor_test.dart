// import 'package:dio/dio.dart';
// import 'package:mocktail/mocktail.dart';
// import 'package:net_kit/net_kit.dart';
// import 'package:test/test.dart';

// // Mock classes
// class MockNetKitManager extends Mock implements NetKitManager {}
// class MockErrorInterceptorHandler extends Mock implements ErrorInterceptorHandler {}

// void main() {
//   late MockNetKitManager netKitManager;
//   late ErrorHandlingInterceptor interceptor;

//   setUp(() {
//     netKitManager = MockNetKitManager();
//     interceptor = ErrorHandlingInterceptor(
//       netKitManager: netKitManager,
//       refreshTokenPath: '/refresh-token',
//     );
//   });

//   test('should successfully refresh token and retry request', () async {
//     // Mocking the initial request that fails
//     final errorResponse = DioException(
//       requestOptions: RequestOptions(path: '/some-path'),
//       response: Response(statusCode: 401),
//     );

//     when(() => netKitManager.request<dynamic>(
//       '/some-path',
//       options: any(named: 'options'),
//       data: any(named: 'data'),
//       queryParameters: any(named: 'queryParameters'),
//     )).thenThrow(errorResponse);

//     // Mocking the token refresh request
//     when(() => netKitManager.request<dynamic>(
//       '/refresh-token',
//       options: any(named: 'options'),
//       data: any(named: 'data'),
//       queryParameters: any(named: 'queryParameters'),
//     )).thenAnswer((_) async => Response(
//       data: {'accessToken': 'newAccessToken', 'refreshToken': 'newRefreshToken'},
//       statusCode: 200,
//     ));

//     // Mocking the retried request after successful token refresh
//     when(() => netKitManager.request<dynamic>(
//       '/some-path',
//       options: any(named: 'options'),
//       data: any(named: 'data'),
//       queryParameters: any(named: 'queryParameters'),
//     )).thenAnswer((_) async => Response(data: 'Success', statusCode: 200));

//     final handler = MockErrorInterceptorHandler();

//     await interceptor._addInterceptor().onError(errorResponse, handler);

//     // Verify that the token was refreshed and the request retried
//     verify(() => netKitManager.request<dynamic>(
//       '/refresh-token',
//       options: any(named: 'options'),
//       data: any(named: 'data'),
//       queryParameters: any(named: 'queryParameters'),
//     )).called(1);

//     verify(() => netKitManager.request<dynamic>(
//       '/some-path',
//       options: any(named: 'options'),
//       data: any(named: 'data'),
//       queryParameters: any(named: 'queryParameters'),
//     )).called(1);

//     verify(() => handler.resolve(any())).called(1);
//   });

//   test('should queue requests while token is refreshing', () async {
//     // Initial request fails
//     final errorResponse = DioException(
//       requestOptions: RequestOptions(path: '/some-path'),
//       response: Response(statusCode: 401),
//     );

//     when(() => netKitManager.request<dynamic>(
//       '/some-path',
//       options: any(named: 'options'),
//       data: any(named: 'data'),
//       queryParameters: any(named: 'queryParameters'),
//     )).thenThrow(errorResponse);

//     // Mocking token refresh request
//     when(() => netKitManager.request<dynamic>(
//       '/refresh-token',
//       options: any(named: 'options'),
//       data: any(named: 'data'),
//       queryParameters: any(named: 'queryParameters'),
//     )).thenAnswer((_) async {
//       await Future.delayed(Duration(seconds: 1)); // Simulate network delay
//       return Response(data: {'accessToken': 'newAccessToken', 'refreshToken': 'newRefreshToken'}, statusCode: 200);
//     });

//     final handler1 = MockErrorInterceptorHandler();
//     final handler2 = MockErrorInterceptorHandler();

//     // First request
//     await interceptor._addInterceptor().onError(errorResponse, handler1);

//     // Second request that should be queued
//     await interceptor._addInterceptor().onError(errorResponse, handler2);

//     // Wait for the token refresh to complete
//     await Future.delayed(Duration(seconds: 2));

//     // Verify that both requests were retried
//     verify(() => handler1.resolve(any())).called(1);
//     verify(() => handler2.resolve(any())).called(1);
//   });

//   test('should return error if token refresh fails', () async {
//     // Initial request fails
//     final errorResponse = DioException(
//       requestOptions: RequestOptions(path: '/some-path'),
//       response: Response(statusCode: 401),
//     );

//     when(() => netKitManager.request<dynamic>(
//       '/some-path',
//       options: any(named: 'options'),
//       data: any(named: 'data'),
//       queryParameters: any(named: 'queryParameters'),
//     )).thenThrow(errorResponse);

//     // Mocking the token refresh request to fail
//     when(() => netKitManager.request<dynamic>(
//       '/refresh-token',
//       options: any(named: 'options'),
//       data: any(named: 'data'),
//       queryParameters: any(named: 'queryParameters'),
//     )).thenThrow(Exception('Token refresh failed'));

//     final handler = MockErrorInterceptorHandler();

//     await interceptor._addInterceptor().onError(errorResponse, handler);

//     // Verify that the error was passed to the handler
//     verify(() => handler.reject(any())).called(1);
//   });
// }
