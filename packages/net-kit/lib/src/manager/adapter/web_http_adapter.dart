import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

import 'i_http_adapter.dart';

/// The class implements the IHttpAdapter interface
/// and returns an instance of the BrowserHttpClientAdapter class
/// for working with the browser.
class WebHttpAdapter implements IHttpAdapter {
  @override
  HttpClientAdapter getAdapter() {
    /// Workaround for the issue with the browser adapter
    /// https://github.com/cfug/dio/issues/2282#issuecomment-2293342475
    final adapter = HttpClientAdapter() as BrowserHttpClientAdapter
      ..withCredentials = true;
    return adapter;
  }
}
