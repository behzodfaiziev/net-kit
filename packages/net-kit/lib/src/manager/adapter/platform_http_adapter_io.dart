import 'i_http_adapter.dart';
import 'io_http_adapter.dart';

/// The class implements the IHttpAdapter interface
IHttpAdapter createPlatformAdapter() => IoHttpAdapter();
