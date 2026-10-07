part of '../net_kit_manager.dart';

/// One API call as described by the public request methods, before it is
/// turned into a transport request.
final class _Call {
  _Call({
    required this.path,
    required this.method,
    this.body,
    this.contentType,
    Map<String, String>? headers,
    this.queryParameters,
    this.timeout,
    this.cancellationToken,
    this.onSendProgress,
    this.onReceiveProgress,
    this.authPolicy = AuthPolicy.inherit,
    this.allowRetryOn401 = false,
    this.idempotencyKey,
  }) : headers = headers ?? const {};

  final String path;
  final String method;
  final RawHttpBody? body;
  final String? contentType;
  final Map<String, String> headers;
  final Map<String, dynamic>? queryParameters;
  final NetKitTimeout? timeout;
  final NetKitCancellationToken? cancellationToken;
  final NetKitProgressCallback? onSendProgress;
  final NetKitProgressCallback? onReceiveProgress;
  final AuthPolicy authPolicy;
  final bool allowRetryOn401;
  final String? idempotencyKey;
}

/// A successful (2xx) transport response with its decoded body.
final class _Outcome {
  const _Outcome(this.response, this.data);

  final RawHttpResponse response;

  /// `null` for an empty body, a `Map`/`List` for JSON, otherwise a `String`.
  final Object? data;

  int get statusCode => response.statusCode;
}

/// Request pipeline: URL resolution, origin policy, header merging, auth
/// policy, interceptors, redirects, and the single refresh-and-retry.
mixin RequestManagerMixin {
  /// The error params for the network manager
  NetKitErrorParams get _errorParams;

  /// The parameters for the network manager
  NetKitParams get parameters;

  /// The logger for the network manager
  INetKitLogger get _logger;

  /// Whether the internet is enabled
  bool get _internetEnabled;

  /// The transport requests are sent through
  NetKitTransport get transport;

  /// Provided by [TokenManagerMixin].
  Future<void> _refreshAfterUnauthorized(
    NetKitCancellationToken? cancellationToken,
  );

  /// Provided by [TokenManagerMixin]: true after the refresh endpoint
  /// rejected the session, until new credentials are stored.
  bool get _refreshBlocked;

  /// Provided by [TokenManagerMixin].
  String? get _accessTokenValue;

  /// Provided by [ErrorHandlingMixin].
  ApiException _fromRawException(RawHttpException exception);

  static const int _maxRedirects = 5;
  static const Set<int> _redirectStatuses = {301, 302, 303, 307, 308};

  /// Runs [call], decodes a successful response with [decode], and maps every
  /// failure to an [ApiException] that has passed through the interceptors'
  /// `onError` hook. Non-`Exception` errors (for example a `TypeError` from a
  /// model) propagate unchanged.
  Future<T> _execute<T>(_Call call, T Function(_Outcome outcome) decode) async {
    RawHttpRequest? lastRequest;
    try {
      _ensureOnline();
      final uri = _resolveUri(call.path, call.queryParameters);
      final foreign = _isForeignOrigin(uri);
      if (foreign && !parameters.allowCrossOriginRequests) {
        throw _crossOriginBlocked();
      }
      if (call.authPolicy == AuthPolicy.required) {
        if (foreign) {
          throw _crossOriginBlocked();
        }
        if (_accessTokenValue == null) {
          throw ApiException(
            type: ApiFailureType.auth,
            statusCode: HttpStatuses.unauthorized.code,
            message: _errorParams.missingAccessTokenError,
          );
        }
      }

      var retried = false;
      while (true) {
        final request = _toRawRequest(call, uri, foreign: foreign);
        lastRequest = request;
        final (response, _) = await _dispatch(request);

        // An ordinary 401 only means the access token may be stale. It can
        // start (or join) one refresh; it never ends the session by itself.
        if (response.statusCode == HttpStatuses.unauthorized.code &&
            !retried &&
            _canRefresh(call, uri)) {
          retried = true;
          _logger.debug('Unauthorized request, refreshing token...');
          await _refreshAfterUnauthorized(call.cancellationToken);
          if (call.cancellationToken?.isCancelled ?? false) {
            throw _cancelled();
          }
          if (!_canRetryOn401(call.method, call.allowRetryOn401)) {
            throw ApiException(
              type: ApiFailureType.auth,
              statusCode: HttpStatuses.unauthorized.code,
              message: _errorParams.nonIdempotentRetryBlockedError,
            );
          }
          if (!(call.body?.isReplayable ?? true)) {
            throw ApiException(
              type: ApiFailureType.invalidRequest,
              statusCode: HttpStatuses.badRequest.code,
              message: _errorParams.nonReplayableBodyError,
            );
          }
          _logger.debug('Retrying ${call.method} after refresh');
          continue;
        }

        final data = _decodeBody(response);
        if (_isRequestFailed(response.statusCode)) {
          throw ApiException.fromJson(
            json: data,
            statusCode: response.statusCode,
            params: _errorParams,
          );
        }
        return decode(_Outcome(response, data));
      }
    } on ApiException catch (error) {
      throw await _notifyError(lastRequest, error);
    } on RawHttpException catch (error) {
      throw await _notifyError(lastRequest, _fromRawException(error));
    } on Exception catch (error) {
      throw await _notifyError(
        lastRequest,
        ApiException(
          type: ApiFailureType.unknown,
          statusCode: HttpStatuses.internalServerError.code,
          message: error.toString(),
          error: error,
        ),
      );
    }
  }

  /// Sends [initial] through the interceptors and the transport, following
  /// redirects under the origin policy. Transport failures become
  /// [ApiException]s.
  ///
  /// Returns the final response and the status the transport reported for
  /// it, before any interceptor could replace the response. With [refresh],
  /// redirects may never leave the API origin and a response produced by a
  /// redirect the HTTP client followed on its own is rejected.
  Future<(RawHttpResponse, int)> _dispatch(
    RawHttpRequest initial, {
    bool refresh = false,
  }) async {
    var request = initial;
    var redirects = 0;
    while (true) {
      final beforeInterceptors = request;
      for (final interceptor in parameters.interceptors) {
        request = await interceptor.onRequest(request);
      }
      request = _enforceOriginAfterInterceptors(
        beforeInterceptors,
        request,
        refresh: refresh,
      );
      RawHttpResponse response;
      try {
        response = await transport.send(request);
      } on RawHttpException catch (error) {
        throw _fromRawException(error);
      }
      final transportStatus = response.statusCode;
      if (refresh && response.redirected) {
        throw ApiException(
          type: ApiFailureType.invalidRequest,
          statusCode: transportStatus,
          message: _errorParams.unverifiedRedirectError,
        );
      }
      for (final interceptor in parameters.interceptors) {
        response = await interceptor.onResponse(request, response);
      }

      final target = _redirectTarget(request, response);
      if (target == null) {
        return (response, transportStatus);
      }
      if (++redirects > _maxRedirects) {
        throw ApiException(
          type: ApiFailureType.invalidRequest,
          statusCode: response.statusCode,
          message: _errorParams.tooManyRedirectsError,
        );
      }
      request = _followRedirect(
        request,
        response.statusCode,
        target,
        refresh: refresh,
      );
    }
  }

  /// Applies the origin policy to a request an interceptor may have
  /// rewritten. Interceptors cannot move a refresh request off the API
  /// origin, cannot reach a blocked origin, and cannot carry the stored or
  /// sensitive headers to an origin the request did not start on.
  RawHttpRequest _enforceOriginAfterInterceptors(
    RawHttpRequest before,
    RawHttpRequest after, {
    required bool refresh,
  }) {
    final uri = after.uri;
    final blocked = refresh
        ? !_isApiOrigin(uri)
        : _isForeignOrigin(uri) && !parameters.allowCrossOriginRequests;
    if (blocked) {
      throw _crossOriginBlocked();
    }
    if (uri.origin == before.uri.origin) {
      return after;
    }
    final headers = Map<String, String>.from(after.headers);
    _stripCredentialHeaders(headers);
    return after.copyWith(headers: headers);
  }

  Uri? _redirectTarget(RawHttpRequest request, RawHttpResponse response) {
    if (!_redirectStatuses.contains(response.statusCode)) {
      return null;
    }
    final location = response.header('location');
    if (location == null || location.isEmpty) {
      return null;
    }
    return request.uri.resolve(location);
  }

  /// Builds the request for a redirect.
  ///
  /// `303`, and `301`/`302` after a `POST`, switch to a body-less `GET`.
  /// Other statuses keep the method and body, which must be replayable. A
  /// redirect to another origin than the request is only followed when
  /// cross-origin requests are allowed, and then without stored or sensitive
  /// headers so credentials never move to another host.
  RawHttpRequest _followRedirect(
    RawHttpRequest request,
    int statusCode,
    Uri target, {
    required bool refresh,
  }) {
    final blocked = refresh
        ? !_isApiOrigin(target)
        : _isForeignOrigin(target) && !parameters.allowCrossOriginRequests;
    if (blocked) {
      throw _crossOriginBlocked();
    }

    var method = request.method;
    var body = request.body;
    final headers = Map<String, String>.from(request.headers);

    final toGet = statusCode == 303 ||
        ((statusCode == 301 || statusCode == 302) &&
            method == RawHttpMethod.post);
    if (toGet) {
      method = RawHttpMethod.get;
      body = null;
      _removeHeader(headers, 'content-type');
      _removeHeader(headers, 'content-length');
    } else if (body != null && !body.isReplayable) {
      throw ApiException(
        type: ApiFailureType.invalidRequest,
        statusCode: statusCode,
        message: _errorParams.nonReplayableBodyError,
      );
    }

    if (target.origin != request.uri.origin) {
      _stripCredentialHeaders(headers);
    }

    _logger.debug('Following $statusCode redirect to ${_logUri(target)}');
    return request.copyWith(
      uri: target,
      method: method,
      headers: headers,
      body: body,
      clearBody: body == null,
    );
  }

  RawHttpRequest _toRawRequest(_Call call, Uri uri, {required bool foreign}) {
    final headers = <String, String>{};
    if (!foreign) {
      parameters.headers
          .forEach((key, value) => _putHeader(headers, key, value));
    }
    call.headers.forEach((key, value) => _putHeader(headers, key, value));
    if (call.body != null && call.contentType != null) {
      _putHeader(headers, 'Content-Type', call.contentType!);
    }
    if (call.idempotencyKey != null) {
      _putHeader(headers, 'Idempotency-Key', call.idempotencyKey!);
    }
    if (call.authPolicy == AuthPolicy.none) {
      _removeHeader(headers, parameters.accessTokenHeaderKey);
    }

    return RawHttpRequest(
      uri: uri,
      method: _rawMethod(call.method),
      headers: headers,
      body: call.body,
      timeout: parameters.timeout.merge(call.timeout),
      cancellationToken: call.cancellationToken,
      onSendProgress: call.onSendProgress,
      onReceiveProgress: call.onReceiveProgress,
    );
  }

  RawHttpMethod _rawMethod(String method) {
    final lower = method.toLowerCase();
    return RawHttpMethod.values.firstWhere(
      (value) => value.name == lower,
      orElse: () => throw ArgumentError.value(
        method,
        'method',
        'Unsupported HTTP method',
      ),
    );
  }

  bool _canRefresh(_Call call, Uri uri) {
    return call.authPolicy != AuthPolicy.none &&
        parameters.refreshTokenPath != null &&
        !_refreshBlocked &&
        !_isRefreshTokenPath(uri.path);
  }

  bool _canRetryOn401(String method, bool allowRetryOn401) {
    if (allowRetryOn401) {
      return true;
    }
    final upper = method.toUpperCase();
    return upper == 'GET' || upper == 'PUT' || upper == 'DELETE';
  }

  bool _isRefreshTokenPath(String path) {
    final refreshPath = parameters.refreshTokenPath;
    if (refreshPath == null) {
      return false;
    }
    final resolved = _resolveUri(refreshPath, null).path;
    return _normalizePath(path) == _normalizePath(resolved);
  }

  String _normalizePath(String path) {
    return path.split('?').first.replaceAll(RegExp(r'^/+|/+$'), '');
  }

  /// Joins [path] with the base URL unless it is already absolute, then
  /// appends [queryParameters]. Absolute URLs without extra query parameters
  /// are returned byte for byte, so signed URLs stay intact.
  Uri _resolveUri(String path, Map<String, dynamic>? queryParameters) {
    final parsed = Uri.tryParse(path);
    Uri uri;
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      uri = parsed;
    } else {
      final base = parameters.baseUrl;
      final String joined;
      if (path.isEmpty) {
        joined = base;
      } else if (base.endsWith('/') && path.startsWith('/')) {
        joined = base + path.substring(1);
      } else if (!base.endsWith('/') && !path.startsWith('/')) {
        joined = '$base/$path';
      } else {
        joined = base + path;
      }
      uri = Uri.parse(joined);
    }

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    final merged = <String, Object>{
      for (final entry in uri.queryParametersAll.entries)
        entry.key: List<String>.of(entry.value),
    };
    queryParameters.forEach((key, value) {
      if (value == null) {
        return;
      }
      final values = value is Iterable
          ? value.where((v) => v != null).map((v) => v.toString()).toList()
          : <String>[value.toString()];
      final existing = merged[key];
      merged[key] =
          existing is List<String> ? [...existing, ...values] : values;
    });
    return uri.replace(queryParameters: merged);
  }

  /// Whether [uri] is an `http(s)` URL on a different origin than the base.
  bool _isForeignOrigin(Uri uri) {
    final base = Uri.tryParse(parameters.baseUrl);
    if (base == null || !_hasHttpOrigin(base) || !_hasHttpOrigin(uri)) {
      return false;
    }
    return uri.origin != base.origin;
  }

  /// Whether [uri] is an `http(s)` URL on exactly the base URL's origin.
  bool _isApiOrigin(Uri uri) {
    final base = Uri.tryParse(parameters.baseUrl);
    return base != null &&
        _hasHttpOrigin(base) &&
        _hasHttpOrigin(uri) &&
        uri.origin == base.origin;
  }

  /// [uri] as text with credentials in the query or user-info redacted.
  String _logUri(Uri uri) =>
      redactUriForLog(uri, parameters.sensitiveQueryParameters);

  /// [path] as text with credentials in the query redacted.
  String _logPath(String path) =>
      redactPathForLog(path, parameters.sensitiveQueryParameters);

  static bool _hasHttpOrigin(Uri uri) {
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// Decodes the body: `null` when empty, JSON when the content type is a
  /// JSON media type or absent (falling back to text when parsing fails),
  /// otherwise the UTF-8 text.
  Object? _decodeBody(RawHttpResponse response) {
    if (response.statusCode == HttpStatuses.noContent.code ||
        response.bodyBytes.isEmpty) {
      return null;
    }
    final text = response.bodyText;
    if (_isJsonMediaType(response.header('content-type'))) {
      try {
        return jsonDecode(text);
      } on FormatException {
        return text;
      }
    }
    return text;
  }

  static bool _isJsonMediaType(String? contentType) {
    if (contentType == null) {
      return true;
    }
    final mime = contentType.split(';').first.trim().toLowerCase();
    return mime == 'application/json' ||
        mime == 'text/json' ||
        mime.endsWith('+json');
  }

  /// Encodes a request body and resolves its content type.
  ///
  /// Maps and lists are JSON by default, or form-urlencoded when
  /// [contentType] says so. Strings and byte lists are sent as-is.
  (RawHttpBody?, String?) _encodeBody(Object? data, String? contentType) {
    switch (data) {
      case null:
        return (null, null);
      case RawHttpBody():
        return (data, contentType);
      case String():
        return (StringRawHttpBody(data), contentType);
      case List<int>():
        return (
          BytesRawHttpBody(data),
          contentType ?? 'application/octet-stream'
        );
      case Map() || List():
        final resolved = contentType ?? 'application/json; charset=utf-8';
        if (resolved
            .toLowerCase()
            .startsWith('application/x-www-form-urlencoded')) {
          if (data is! Map) {
            throw ArgumentError.value(data, 'body', 'Form body must be a map');
          }
          return (StringRawHttpBody(_formEncode(data)), resolved);
        }
        try {
          return (BytesRawHttpBody(utf8.encode(jsonEncode(data))), resolved);
          // `jsonEncode` reports an unencodable value as an Error; it is a
          // caller input problem, so surface it as an ApiException.
          // ignore: avoid_catching_errors
        } on JsonUnsupportedObjectError catch (error) {
          throw ApiException(
            type: ApiFailureType.invalidRequest,
            statusCode: HttpStatuses.badRequest.code,
            message: _errorParams.jsonUnsupportedObjectError,
            error: error,
          );
        }
      default:
        throw ArgumentError.value(
          data,
          'body',
          'Unsupported body type ${data.runtimeType}',
        );
    }
  }

  static String _formEncode(Map<dynamic, dynamic> data) {
    final params = <String, Object>{};
    data.forEach((key, value) {
      if (value == null) {
        return;
      }
      params['$key'] = value is Iterable
          ? value.map((v) => v.toString()).toList()
          : value.toString();
    });
    return Uri(queryParameters: params).query;
  }

  /// Removes the stored headers and every sensitive header from [headers].
  void _stripCredentialHeaders(Map<String, String> headers) {
    for (final key in parameters.headers.keys) {
      _removeHeader(headers, key);
    }
    for (final name in parameters.sensitiveHeaders) {
      _removeHeader(headers, name);
    }
    _removeHeader(headers, parameters.accessTokenHeaderKey);
  }

  static void _putHeader(
    Map<String, String> headers,
    String key,
    String value,
  ) {
    _removeHeader(headers, key);
    headers[key] = value;
  }

  static void _removeHeader(Map<String, String> headers, String key) {
    final lower = key.toLowerCase();
    headers.removeWhere((existing, _) => existing.toLowerCase() == lower);
  }

  static String? _headerValue(Map<String, String>? headers, String key) {
    if (headers == null) {
      return null;
    }
    final lower = key.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lower) {
        return entry.value;
      }
    }
    return null;
  }

  void _ensureOnline() {
    if (!_internetEnabled) {
      throw ApiException(
        type: ApiFailureType.transport,
        message: _errorParams.noInternetError,
        statusCode: HttpStatuses.serviceUnavailable.code,
      );
    }
  }

  ApiException _crossOriginBlocked() => ApiException(
        type: ApiFailureType.invalidRequest,
        statusCode: HttpStatuses.badRequest.code,
        message: _errorParams.crossOriginRequestBlockedError,
      );

  ApiException _cancelled() => ApiException(
        type: ApiFailureType.cancelled,
        statusCode: null,
        message: _errorParams.requestCancelledError,
      );

  Future<ApiException> _notifyError(
    RawHttpRequest? request,
    ApiException error,
  ) async {
    var current = error;
    for (final interceptor in parameters.interceptors) {
      current = await interceptor.onError(request, current);
    }
    return current;
  }

  /// Checks if the request failed based on the status code
  bool _isRequestFailed(int? statusCode) {
    if (statusCode == null) {
      return true;
    }
    return statusCode < HttpStatuses.ok.code ||
        statusCode >= HttpStatuses.multipleChoices.code;
  }

  bool _hasEmptyResponseBody(_Outcome outcome) {
    if (outcome.statusCode == HttpStatuses.noContent.code) {
      return true;
    }
    final data = outcome.data;
    return data == null || (data is String && data.isEmpty);
  }

  void _logResponse(String path, _Outcome outcome) {
    if (parameters.logResponseBodies) {
      _logger
          .debug('Response received from ${_logPath(path)}: ${outcome.data}');
    } else {
      _logger.debug(
        'Response received from ${_logPath(path)}: '
        'status ${outcome.statusCode}, '
        '${outcome.response.bodyBytes.length} bytes',
      );
    }
  }
}
