import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'i_http_adapter.dart';

/// The class implements the IHttpAdapter interface
/// and returns an instance of the IOHttpClientAdapter class
/// for the native platforms except for the browser.
class IoHttpAdapter implements IHttpAdapter {
  @override
  HttpClientAdapter getAdapter() {
    return IOHttpClientAdapter();
  }
}
