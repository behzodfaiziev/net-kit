import 'i_http_adapter.dart';
import 'io_http_adapter.dart';

/// Creates the `dart:io` adapter factory. [withCredentials] is a browser-only
/// setting and is ignored here.
IHttpAdapter createPlatformAdapter({required bool withCredentials}) =>
    IoHttpAdapter();
