/// A lightweight abstraction around an HTTP request.
/// This is used in ['onBeforeRefreshRequest'] to mutate the request dynamically
/// before it is sent.
class NetKitRequestOptions {
  /// Constructor for the request options
  NetKitRequestOptions({
    required this.path,
    required this.method,
    Map<String, dynamic>? headers,
    this.data,
    this.contentType,
  }) : headers = headers ?? <String, dynamic>{};

  /// The full path or endpoint of the request (e.g. `/auth/refresh-token`)
  String path;

  /// HTTP method: GET, POST, etc.
  String method;

  /// Request headers
  Map<String, dynamic> headers;

  /// The request body (can be Map, FormData, etc.)
  dynamic data;

  /// Optional content type (e.g. `application/json`)
  String? contentType;
}
