import 'dart:convert';

/// Header access shared by buffered and streamed transport responses.
mixin RawHttpResponseView {
  /// HTTP status code as returned by the server.
  int get statusCode;

  /// Response headers. Keys are not normalized. Transports supply an
  /// unmodifiable map of unmodifiable lists.
  Map<String, List<String>> get headers;

  /// Whether the HTTP client followed at least one redirect on its own
  /// before producing this response.
  ///
  /// The transport asks the client not to follow redirects, but browsers
  /// follow them unconditionally and only report that they did. When this is
  /// true the response may come from a different URL, possibly on another
  /// origin, than the request.
  bool get redirected;

  /// Whether [statusCode] is in the `2xx` range.
  bool get isSuccessful => statusCode >= 200 && statusCode < 300;

  /// Parsed `Content-Length` header, or `null` when absent or malformed.
  int? get contentLength {
    final value = header('content-length');
    return value == null ? null : int.tryParse(value.trim());
  }

  /// Case-insensitive header lookup returning the **first** value.
  ///
  /// Returns `null` when the header is absent. Use [headerValues] for
  /// headers that may repeat, such as `Set-Cookie`.
  String? header(String name) {
    final values = headerValues(name);
    return values.isEmpty ? null : values.first;
  }

  /// Case-insensitive lookup of every value sent for [name].
  ///
  /// Returns an empty list when the header is absent. The returned list is
  /// unmodifiable.
  List<String> headerValues(String name) {
    final target = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == target) {
        return List<String>.unmodifiable(entry.value);
      }
    }
    return const [];
  }
}

/// Buffered transport response with no API or model interpretation.
///
/// The whole body is held in memory as [bodyBytes]. For large downloads use
/// `NetKitTransport.sendStreamed`, which returns a streamed response.
final class RawHttpResponse with RawHttpResponseView {
  /// Creates a buffered transport response.
  const RawHttpResponse({
    required this.statusCode,
    required this.headers,
    this.bodyBytes = const [],
    this.redirected = false,
  });

  @override
  final int statusCode;

  @override
  final Map<String, List<String>> headers;

  @override
  final bool redirected;

  /// Response body bytes. Empty when the server sent no body.
  final List<int> bodyBytes;

  /// [bodyBytes] decoded as UTF-8. Malformed sequences are replaced.
  String get bodyText => utf8.decode(bodyBytes, allowMalformed: true);
}
