import 'package:dio/browser.dart';

import '../../../net_kit.dart';
import 'i_http_adapter.dart';

/// The class implements the IHttpAdapter interface
/// and returns an instance of the BrowserHttpClientAdapter class
/// for working with the browser.
class HttpAdapter implements IHttpAdapter {
  @override
  HttpClientAdapter getAdapter() {
    return BrowserHttpClientAdapter();
  }
}
