import 'package:dio/dio.dart';

/// The abstract class declares the method for getting the adapter.
abstract class IHttpAdapter {
  /// Returns the adapter
  HttpClientAdapter getAdapter();
}
