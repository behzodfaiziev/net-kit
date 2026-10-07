import 'i_http_adapter.dart';
import 'web_http_adapter.dart';

/// Creates the browser adapter factory.
IHttpAdapter createPlatformAdapter({required bool withCredentials}) =>
    WebHttpAdapter(withCredentials: withCredentials);
