import 'i_http_adapter.dart';

/// The class implements the IHttpAdapter interface
IHttpAdapter createPlatformAdapter() {
  throw UnsupportedError('No adapter available for this platform.');
}
