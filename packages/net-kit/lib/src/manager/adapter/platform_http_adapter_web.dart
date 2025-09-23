import 'i_http_adapter.dart';
import 'web_http_adapter.dart';

/// The class implements the IHttpAdapter interface
IHttpAdapter createPlatformAdapter() => const WebHttpAdapter();
