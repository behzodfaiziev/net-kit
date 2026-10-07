/// Dio adapter entrypoint.
///
/// `package:net_kit/net_kit.dart` exposes only net_kit-owned types. Import
/// this library when you need the Dio-backed transport explicitly, for
/// example to construct a `RawHttpClient` without a `NetKitManager`, to
/// inject a custom `HttpClientAdapter`, or to use Dio types alongside
/// net_kit.
library;

export 'package:dio/dio.dart';

export 'src/raw/dio/dio_net_kit_transport.dart';
