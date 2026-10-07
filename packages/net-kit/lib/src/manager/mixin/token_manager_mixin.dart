part of '../net_kit_manager.dart';

/// Thrown inside the refresh routine when the refresh endpoint answered
/// HTTP `401` at the transport level. Never escapes the manager.
final class _RefreshRejected implements Exception {
  const _RefreshRejected(this.exception);

  final ApiException exception;
}

/// Access/refresh token storage and the single-flight refresh.
///
/// Session invariant: the stored tokens are cleared and
/// `onSessionInvalidated` is called **only** when the refresh endpoint
/// answers HTTP `401`. Every other refresh failure (offline, DNS, TLS,
/// timeout, cancellation, `429`, `5xx`, other `4xx`, malformed or token-less
/// `2xx`) is reported to the waiting requests with its own classification and
/// leaves the tokens untouched, so a later request can refresh again.
mixin TokenManagerMixin on RequestManagerMixin, ErrorHandlingMixin {
  String? _refreshToken;

  /// The refresh shared by every request that is waiting on it.
  Future<void>? _refreshInFlight;

  /// Incremented whenever application code changes credentials. A refresh
  /// whose result arrives after such a change is stale and is discarded.
  int _credentialGeneration = 0;

  /// Set after the refresh endpoint rejected the session; cleared when the
  /// application stores new credentials. While set, a `401` is returned to
  /// the caller without another refresh attempt.
  bool _sessionInvalidated = false;

  @override
  bool get _refreshBlocked => _sessionInvalidated;

  @override
  String? get _accessTokenValue => RequestManagerMixin._headerValue(
        parameters.headers,
        parameters.accessTokenHeaderKey,
      );

  /// Records an application-initiated credential change.
  void _credentialsChanged() {
    _credentialGeneration++;
    _sessionInvalidated = false;
  }

  /// Implementation of setting the access token
  void _setAccessToken(String? token) {
    if (token == null) return;
    if (parameters.devMode && RegExp(r'\s').hasMatch(token)) {
      _logger.warning(
        'Access token contains whitespace or newlines (RFC 6750)',
      );
    }
    final prefix = parameters.accessTokenPrefix;
    final normalized = token.startsWith('$prefix ') ? token : '$prefix $token';
    RequestManagerMixin._putHeader(
      parameters.headers,
      parameters.accessTokenHeaderKey,
      normalized,
    );
  }

  /// Implementation of setting the refresh token
  void _setRefreshToken(String? token) {
    if (token == null) return;
    _refreshToken = token;
  }

  /// Implementation of removing the access token
  void _removeAccessToken() {
    RequestManagerMixin._removeHeader(
      parameters.headers,
      parameters.accessTokenHeaderKey,
    );
  }

  /// Implementation of removing the refresh token
  void _removeRefreshToken() {
    _refreshToken = null;
  }

  /// Waits for the single shared refresh, starting it when none is running.
  ///
  /// [cancellationToken] belongs to the waiting request only: cancelling it
  /// stops this request from waiting (and from retrying) but never cancels
  /// the refresh other requests depend on.
  @override
  Future<void> _refreshAfterUnauthorized(
    NetKitCancellationToken? cancellationToken,
  ) async {
    var refresh = _refreshInFlight;
    if (refresh == null) {
      final completer = Completer<void>();
      refresh = completer.future;
      _refreshInFlight = refresh;
      // Waiters may all be cancelled; keep a refresh failure from surfacing
      // as an unhandled error in that case.
      unawaited(refresh.then<void>((_) {}, onError: (Object _) {}));
      unawaited(_runRefresh(completer));
    }
    await _awaitRefresh(refresh, cancellationToken);
  }

  Future<void> _awaitRefresh(
    Future<void> refresh,
    NetKitCancellationToken? cancellationToken,
  ) async {
    if (cancellationToken == null) {
      return refresh;
    }
    final cancelled = Completer<void>();
    final unbind = bindNetKitCancellationToken(
      cancellationToken,
      () => cancelled.isCompleted ? null : cancelled.complete(),
    );
    try {
      await Future.any([refresh, cancelled.future]);
    } finally {
      unbind();
    }
    if (cancellationToken.isCancelled) {
      throw _cancelled();
    }
  }

  /// Performs one refresh and settles [completer] for every waiter.
  ///
  /// The in-flight slot is released before any application callback runs,
  /// so a callback that issues a request starts a fresh refresh instead of
  /// joining this finished one, and a throwing callback cannot leave the
  /// slot occupied.
  Future<void> _runRefresh(Completer<void> completer) async {
    final generation = _credentialGeneration;
    void release() {
      if (identical(_refreshInFlight, completer.future)) {
        _refreshInFlight = null;
      }
    }

    try {
      _logger.info('Refreshing token...');
      final tokens = await _requestNewTokens();
      release();
      if (generation != _credentialGeneration) {
        _logger.info('Refreshed tokens discarded: credentials changed.');
      } else {
        _setAccessToken(tokens.accessToken);
        _setRefreshToken(tokens.refreshToken);
        _logger.info('Tokens updated successfully.');
        _invokeCallback(
          'onTokenRefreshed',
          () => parameters.onTokenRefreshed?.call(tokens),
        );
      }
      completer.complete();
    } on _RefreshRejected catch (rejection) {
      release();
      if (generation != _credentialGeneration) {
        // The rejected refresh token is no longer the stored one; the
        // application signed in again meanwhile, so the session is not over.
        _logger.info('Refresh rejected for superseded credentials.');
        completer.complete();
        return;
      }
      _logger.warning('Refresh endpoint answered 401; session invalidated.');
      _removeAccessToken();
      _removeRefreshToken();
      _sessionInvalidated = true;
      _invokeCallback(
        'onSessionInvalidated',
        () => parameters.onSessionInvalidated?.call(rejection.exception),
      );
      completer.completeError(rejection.exception);
    } on ApiException catch (error) {
      release();
      _logger.warning(
        'Token refresh failed (${error.type}, ${error.statusCode}); '
        'session kept.',
      );
      completer.completeError(error.asRefreshFailure());
    } on Object catch (error) {
      release();
      _logger.error('Token refresh failed unexpectedly; session kept.');
      completer.completeError(
        ApiException(
          type: ApiFailureType.unknown,
          statusCode: HttpStatuses.internalServerError.code,
          message: error.toString(),
          error: error,
          fromRefresh: true,
        ),
      );
    }
  }

  /// Runs an application callback without letting it break the pipeline.
  void _invokeCallback(String name, FutureOr<void> Function() callback) {
    try {
      final result = callback();
      if (result is Future<void>) {
        result.catchError((Object error) {
          _logger.error('$name callback failed: $error');
        }).ignore();
      }
    } on Object catch (error) {
      _logger.error('$name callback failed: $error');
    }
  }

  /// Sends the refresh request and returns the new tokens.
  ///
  /// Throws [_RefreshRejected] only when the transport response to the
  /// refresh request has status `401`. Every other failure is a classified
  /// [ApiException].
  Future<AuthTokenModel> _requestNewTokens() async {
    final headers = Map<String, dynamic>.of(parameters.headers);
    if (parameters.removeAccessTokenBeforeRefresh) {
      final key = parameters.accessTokenHeaderKey.toLowerCase();
      headers.removeWhere((name, _) => name.toLowerCase() == key);
    }

    final options = NetKitRequestOptions(
      method: 'POST',
      path: parameters.refreshTokenPath!,
      headers: headers,
      contentType: parameters.refreshTokenContentType ==
              RefreshTokenContentType.formUrlEncoded
          ? 'application/x-www-form-urlencoded'
          : 'application/json; charset=utf-8',
      data: {parameters.refreshTokenBodyKey: _refreshToken},
    );

    parameters.onBeforeRefreshRequest?.call(options);

    await Future<void>.delayed(Duration.zero);
    _ensureOnline();

    // Refresh credentials never leave the API origin, whatever
    // `allowCrossOriginRequests` says.
    final uri = _resolveUri(options.path, null);
    if (!_isApiOrigin(uri)) {
      throw _crossOriginBlocked();
    }

    final (body, contentType) = _encodeBody(options.data, options.contentType);
    final requestHeaders = <String, String>{};
    for (final entry in options.headers.entries) {
      if (entry.value != null) {
        RequestManagerMixin._putHeader(
          requestHeaders,
          entry.key,
          entry.value.toString(),
        );
      }
    }
    if (body != null && contentType != null) {
      RequestManagerMixin._putHeader(
        requestHeaders,
        'Content-Type',
        contentType,
      );
    }

    final (response, transportStatus) = await _dispatch(
      RawHttpRequest(
        uri: uri,
        method: _rawMethod(options.method),
        headers: requestHeaders,
        body: body,
        timeout: parameters.timeout,
      ),
      refresh: true,
    );

    final data = _decodeBody(response);
    if (transportStatus == HttpStatuses.unauthorized.code) {
      final parsed = ApiException.fromJson(
        json: data,
        statusCode: transportStatus,
        params: _errorParams,
      );
      throw _RefreshRejected(
        ApiException(
          type: ApiFailureType.sessionInvalidated,
          statusCode: transportStatus,
          message: data == null
              ? _errorParams.sessionInvalidatedError
              : parsed.message,
          messages: parsed.messages,
          fromRefresh: true,
        ),
      );
    }
    if (_isRequestFailed(response.statusCode)) {
      throw ApiException.fromJson(
        json: data,
        statusCode: response.statusCode,
        params: _errorParams,
      );
    }

    final tokens = extractTokens(statusCode: response.statusCode, data: data);
    if (tokens.accessToken == null || tokens.accessToken!.isEmpty) {
      throw ApiException(
        type: ApiFailureType.decoding,
        message: _errorParams.invalidTokenResponseError,
        statusCode: response.statusCode,
      );
    }
    return tokens;
  }

  /// Extracts the tokens from a decoded refresh response body.
  ///
  /// Returns empty tokens for `5xx` statuses, non-map bodies, or missing or
  /// non-string values.
  @visibleForTesting
  AuthTokenModel extractTokens({
    required int? statusCode,
    required Object? data,
  }) {
    try {
      if ((statusCode ?? 0) >= 500) {
        return const AuthTokenModel();
      }
      final dataKey = parameters.dataKey;
      final Object? container;
      if (dataKey == null) {
        container = data;
      } else {
        container = (data as MapType?)?[dataKey];
      }
      final map = container as MapType?;
      if (map == null) {
        return const AuthTokenModel();
      }
      return AuthTokenModel(
        accessToken: map[parameters.accessTokenBodyKey] as String?,
        refreshToken: map[parameters.refreshTokenBodyKey] as String?,
      );
    } on Object catch (_) {
      return const AuthTokenModel();
    }
  }
}
