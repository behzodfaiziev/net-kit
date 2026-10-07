import 'net_kit_transport.dart';

/// Isolated raw HTTP client: a [NetKitTransport] used directly.
///
/// Sends absolute URLs with caller-owned headers and returns status codes,
/// headers, and bodies without API, auth, or model semantics. The same
/// implementation that backs `NetKitManager` serves as the raw client, so
/// there is one transport layer and one set of body, response, and error
/// types.
typedef RawHttpClient = NetKitTransport;
