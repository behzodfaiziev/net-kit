/// HTTP methods supported by the raw HTTP transport.
///
/// Independent of the API client's request methods so the raw layer can
/// include `HEAD` and `OPTIONS` without changing `NetKitManager`.
enum RawHttpMethod {
  /// GET
  get,

  /// POST
  post,

  /// PUT
  put,

  /// PATCH
  patch,

  /// DELETE
  delete,

  /// HEAD
  head,

  /// OPTIONS
  options,
}

/// Helpers for mapping [RawHttpMethod] to an HTTP verb.
extension RawHttpMethodX on RawHttpMethod {
  /// Upper-case HTTP method name, e.g. `PUT`.
  String get httpName => name.toUpperCase();
}
