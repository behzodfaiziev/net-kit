import 'dart:convert';

import '../../core/net_kit_interceptor.dart';
import '../../raw/raw_http_body.dart';
import '../../raw/raw_http_method.dart';
import '../../raw/raw_http_request.dart';
import '../../raw/raw_http_response.dart';
import '../../utility/log/log_redaction.dart';
import '../error/api_exception.dart';

/// Development log interceptor that never prints secret header values.
///
/// Registered by `NetKitManager(logInterceptorEnabled: true)` in dev mode,
/// or add it to `interceptors` yourself to configure it. It logs the request
/// URL, method, and headers, the response status and headers, and failures,
/// redacting the value of every header in [sensitiveHeaders]. Bodies are
/// printed only when [logBodies] is true, after passing through
/// [bodySanitizer] when one is set.
///
/// URLs are printed with the values of [sensitiveQueryParameters] (signed
/// URL signatures, OAuth codes, API keys, ...) and any user-info redacted.
/// Header and query parameter names are matched case-insensitively.
class RedactingLogInterceptor extends NetKitInterceptor {
  /// Creates a redacting log interceptor.
  ///
  /// [sensitiveHeaders] is merged with [defaultSensitiveHeaders].
  RedactingLogInterceptor({
    Iterable<String> sensitiveHeaders = const [],
    Iterable<String> sensitiveQueryParameters = const [],
    this.logBodies = false,
    this.bodySanitizer,
    this.logPrint = _debugPrint,
  })  : sensitiveHeaders = {
          ...defaultSensitiveHeaders,
          ...sensitiveHeaders.map((name) => name.toLowerCase()),
        },
        sensitiveQueryParameters = {
          ...defaultSensitiveQueryParameters,
          ...sensitiveQueryParameters.map((name) => name.toLowerCase()),
        };

  /// Header names redacted by default.
  static const Set<String> defaultSensitiveHeaders = {
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'api-key',
    'x-auth-token',
    'x-refresh-token',
    'x-csrf-token',
    'x-xsrf-token',
  };

  /// Placeholder printed instead of a sensitive header value.
  static const String redacted = logRedactedValue;

  /// Maximum number of body characters printed.
  static const int maxBodyChars = 4096;

  /// Lower-case header names whose values are redacted.
  final Set<String> sensitiveHeaders;

  /// Lower-case query parameter names whose values are redacted from URLs.
  final Set<String> sensitiveQueryParameters;

  /// Whether in-memory request bodies and response bodies are printed.
  final bool logBodies;

  /// Transforms a body before it is printed, for example to mask tokens.
  final String Function(String body)? bodySanitizer;

  /// Log sink. Defaults to `print` in debug builds only.
  final void Function(Object object) logPrint;

  @override
  RawHttpRequest onRequest(RawHttpRequest request) {
    logPrint('*** Request ***');
    logPrint('uri: ${_uri(request.uri)}');
    logPrint('method: ${request.method.httpName}');
    _printHeaders(request.headers);
    if (logBodies) {
      _printBody(_requestBodyText(request.body));
    }
    logPrint('');
    return request;
  }

  @override
  RawHttpResponse onResponse(RawHttpRequest request, RawHttpResponse response) {
    logPrint('*** Response ***');
    logPrint('uri: ${_uri(request.uri)}');
    logPrint('statusCode: ${response.statusCode}');
    _printHeaders(response.headers);
    if (logBodies) {
      _printBody(response.bodyBytes.isEmpty ? null : response.bodyText);
    }
    logPrint('');
    return response;
  }

  @override
  ApiException onError(RawHttpRequest? request, ApiException error) {
    logPrint('*** ApiException ***');
    if (request != null) {
      logPrint('uri: ${_uri(request.uri)}');
    }
    logPrint('type: ${error.type}');
    logPrint('statusCode: ${error.statusCode}');
    logPrint('message: ${error.message}');
    logPrint('');
    return error;
  }

  String _uri(Uri uri) => redactUriForLog(uri, sensitiveQueryParameters);

  String? _requestBodyText(RawHttpBody? body) {
    return switch (body) {
      null => null,
      StringRawHttpBody(:final value) => value,
      BytesRawHttpBody(:final bytes) =>
        utf8.decode(bytes, allowMalformed: true),
      StreamRawHttpBody() ||
      ReplayableRawHttpBody() ||
      FileRawHttpBody() =>
        '<streamed body>',
      NetKitFormData() => '<multipart body>',
    };
  }

  void _printBody(String? body) {
    if (body == null) {
      return;
    }
    final sanitized = bodySanitizer?.call(body) ?? body;
    final shown = sanitized.length > maxBodyChars
        ? '${sanitized.substring(0, maxBodyChars)}…'
        : sanitized;
    logPrint('body: $shown');
  }

  void _printHeaders(Map<String, Object> headers) {
    logPrint('headers:');
    headers.forEach((key, value) {
      final shown = sensitiveHeaders.contains(key.toLowerCase())
          ? redacted
          : value is List
              ? value.join(', ')
              : value;
      logPrint(' $key: $shown');
    });
  }
}

void _debugPrint(Object? object) {
  assert(
    () {
      // Dev-only console sink.
      // ignore: avoid_print
      print(object);
      return true;
    }(),
    'debug-only print',
  );
}
