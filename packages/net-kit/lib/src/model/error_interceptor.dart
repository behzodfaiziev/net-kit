import 'package:dio/dio.dart';

/// The error interceptor class
class ErrorInterceptor extends InterceptorsWrapper {
  /// The constructor for the error interceptor class
  /// It takes in the following parameters:
  /// `onRequest`, `onResponse`, and `onError`
  /// The `onRequest` parameter is called when the request is made
  /// The `onResponse` parameter is called when the response is received
  /// The `onError` parameter is called when an error occurs
  ErrorInterceptor({
    super.onRequest,
    super.onResponse,
    super.onError,
  });
}
