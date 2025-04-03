export 'platform_http_adapter_stub.dart'
    if (dart.library.io) 'platform_http_adapter_io.dart'
    if (dart.library.html) 'platform_http_adapter_web.dart';
