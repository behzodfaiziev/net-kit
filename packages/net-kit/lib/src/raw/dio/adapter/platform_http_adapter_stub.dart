import 'i_http_adapter.dart';

/// Fallback for platforms with neither `dart:io` nor `dart:html`.
IHttpAdapter createPlatformAdapter({required bool withCredentials}) {
  throw UnsupportedError('No adapter available for this platform.');
}
