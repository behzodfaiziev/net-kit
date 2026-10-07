import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

import '../core/auth_policy.dart';
import '../core/net_kit_cancellation_token.dart';
import '../core/net_kit_interceptor.dart';
import '../core/net_kit_progress_callback.dart';
import '../core/net_kit_request_options.dart';
import '../core/net_kit_timeout.dart';
import '../enum/http_status_codes.dart';
import '../enum/refresh_token_content_type.dart';
import '../enum/request_method.dart';
import '../model/api_meta_response.dart';
import '../model/auth_token_model.dart';
import '../model/i_net_kit_model.dart';
import '../model/void_model.dart';
import '../raw/dio/dio_net_kit_transport.dart';
import '../raw/net_kit_transport.dart';
import '../raw/raw_http_body.dart';
import '../raw/raw_http_exception.dart';
import '../raw/raw_http_method.dart';
import '../raw/raw_http_request.dart';
import '../raw/raw_http_response.dart';
import '../utility/converter.dart';
import '../utility/log/log_redaction.dart';
import '../utility/logger/i_net_kit_logger.dart';
import '../utility/logger/void_logger.dart';
import '../utility/typedef/request_type_def.dart';
import 'error/api_exception.dart';
import 'error/api_failure_type.dart';
import 'i_net_kit_manager.dart';
import 'interceptors/redacting_log_interceptor.dart';
import 'params/net_kit_error_params.dart';
import 'params/net_kit_params.dart';

part 'mixin/error_handling_mixin.dart';
part 'mixin/request_manager_mixin.dart';
part 'mixin/token_manager_mixin.dart';
part 'mixin/upload_manager_mixin.dart';

/// The API client of net_kit.
///
/// `NetKitManager` composes a [NetKitTransport] and adds everything an
/// application API needs on top of raw HTTP: base URL and stored headers,
/// JSON encoding and decoding into [INetKitModel]s, `dataKey` envelopes,
/// access-token injection governed by [AuthPolicy], single-flight token
/// refresh with one retry, origin enforcement, safe redirect handling, and
/// error mapping to [ApiException].
///
/// The transport is Dio by default; pass [transport] to use another one.
/// No transport library type appears in the public API.
class NetKitManager extends INetKitManager
    with
        RequestManagerMixin,
        ErrorHandlingMixin,
        TokenManagerMixin,
        UploadManagerMixin {
  /// The constructor for the NetKitManager class
  NetKitManager({
    /// The base URL for the network requests
    required String baseUrl,

    /// The parameters for error messages and error keys
    NetKitErrorParams? errorParams,

    /// The transport to send requests through. Defaults to the built-in Dio
    /// transport. An injected transport is not closed by [dispose].
    NetKitTransport? transport,

    /// The development base URL for dev mode
    String? devBaseUrl,

    /// Headers sent with every same-origin request, for example
    /// `Accept-Language`. `setAccessToken` and `addHeader` edit this set.
    Map<String, String>? headers,

    /// Manager-wide timeouts. Per-request timeouts are merged over them.
    NetKitTimeout timeout = const NetKitTimeout(),

    /// Application interceptors, run in order after the development log
    /// interceptor (when enabled).
    List<NetKitInterceptor> interceptors = const [],

    /// The callback function that is called before the refresh token request
    OnBeforeRefresh? onBeforeRefreshRequest,

    /// Called once when the **refresh endpoint** answers HTTP `401`, after
    /// the stored tokens have been cleared. This is the only signal that the
    /// session is over; sign the user out here. It is never called for a
    /// `401` from an ordinary request or for offline, timeout, TLS, `429`,
    /// `5xx`, or malformed refresh responses, which leave the session intact.
    OnSessionInvalidated? onSessionInvalidated,

    /// Whether the network manager is in development mode.
    /// If true, `devBaseUrl` is used instead of `baseUrl`, and logging options
    /// (`loggerEnabled`, `logInterceptorEnabled`) are allowed to take effect.
    /// CAUTION: Make sure that it is set to false in production environments.
    bool devMode = false,

    /// The stream for the internet status
    Stream<bool>? internetStatusStream,

    /// The key for the access token in the headers
    String accessTokenHeaderKey = 'Authorization',

    /// The key for the access token in the body
    /// Used for automatic token refresh
    String accessTokenBodyKey = 'accessToken',

    /// The prefix for the access token in the headers
    String accessTokenPrefix = 'Bearer',

    /// Whether to remove the access token header before refreshing the token
    /// Default is true
    bool removeAccessTokenBeforeRefresh = true,

    /// The key for the refresh token in the body
    /// Used for automatic token refresh
    String refreshTokenBodyKey = 'refreshToken',

    /// The path for the refresh token request. When `null`, a `401` is
    /// returned to the caller and no refresh is attempted.
    String? refreshTokenPath,

    /// The key to extract data from the response.
    /// If null, the response data will be used as is.
    String? dataKey,

    /// The key to extract data from the metadata response.
    /// Default value is ['data']
    String metadataDataKey = 'data',

    /// Logger for the network manager. The default logger is VoidLogger
    /// which does not log anything. To enable logging, a custom logger
    /// must be created and injected into the NetKitManager class.
    INetKitLogger logger = const VoidLogger(),

    /// Whether the development HTTP log interceptor is registered. It prints
    /// URLs, methods, statuses, and headers with sensitive values redacted;
    /// bodies only when `logResponseBodies` is true. Only takes effect when
    /// `devMode` is true.
    bool logInterceptorEnabled = false,

    /// Whether the injected `logger` is used for Net-Kit internal logging.
    /// Only takes effect when `devMode` is true.
    bool loggerEnabled = false,

    /// Whether parsed response data is written to the injected logger and
    /// the log interceptor prints bodies. Off by default so tokens and
    /// personal data in responses stay out of logs.
    bool logResponseBodies = false,

    /// The callback function that is called when the tokens are updated
    OnTokenRefreshed? onTokenRefreshed,

    /// Content type for the refresh token request body.
    RefreshTokenContentType refreshTokenContentType =
        RefreshTokenContentType.json,

    /// Whether requests may target an absolute URL whose origin differs from
    /// `baseUrl` (or `devBaseUrl` in dev mode).
    ///
    /// Defaults to false: such requests, and redirects to such URLs, fail
    /// with an `ApiException` (`crossOriginRequestBlockedError`) before
    /// anything is sent. When true, they are sent **without** the stored
    /// headers and access token. Use the transport directly (`RawHttpClient`)
    /// for external URLs such as signed storage uploads.
    bool allowCrossOriginRequests = false,

    /// Additional header names treated as credentials: redacted from the
    /// development log and stripped from cross-origin redirects.
    /// `Authorization`, `Cookie`, `Set-Cookie`, and common API-key headers
    /// are always included.
    Iterable<String> sensitiveHeaders = const [],

    /// Additional query parameter names whose values are redacted from
    /// logged URLs. Common credential names (`token`, `access_token`,
    /// `api_key`, `signature`, `X-Amz-Signature`, `code`, ...) are always
    /// included.
    Iterable<String> sensitiveQueryParameters = const [],
  }) {
    _errorParams = errorParams ?? const NetKitErrorParams();
    _logger = loggerEnabled && devMode ? logger : const VoidLogger();
    _converter = const Converter();
    _ownsTransport = transport == null;
    this.transport =
        transport ?? DioNetKitTransport(browserWithCredentials: true);

    final sensitive = <String>{
      ...RedactingLogInterceptor.defaultSensitiveHeaders,
      ...sensitiveHeaders.map((name) => name.toLowerCase()),
      accessTokenHeaderKey.toLowerCase(),
    };

    final sensitiveQuery = <String>{
      ...defaultSensitiveQueryParameters,
      ...sensitiveQueryParameters.map((name) => name.toLowerCase()),
      accessTokenBodyKey.toLowerCase(),
      refreshTokenBodyKey.toLowerCase(),
    };

    parameters = NetKitParams(
      baseUrl: devMode ? devBaseUrl ?? baseUrl : baseUrl,
      headers: Map<String, String>.from(headers ?? const {}),
      timeout: timeout,
      interceptors: List<NetKitInterceptor>.unmodifiable([
        if (logInterceptorEnabled && devMode)
          RedactingLogInterceptor(
            sensitiveHeaders: sensitive,
            sensitiveQueryParameters: sensitiveQuery,
            logBodies: logResponseBodies,
          ),
        ...interceptors,
      ]),
      devMode: devMode,
      accessTokenHeaderKey: accessTokenHeaderKey,
      accessTokenBodyKey: accessTokenBodyKey,
      accessTokenPrefix: accessTokenPrefix,
      refreshTokenBodyKey: refreshTokenBodyKey,
      onBeforeRefreshRequest: onBeforeRefreshRequest,
      onSessionInvalidated: onSessionInvalidated,
      onTokenRefreshed: onTokenRefreshed,
      metadataDataKey: metadataDataKey,
      dataKey: dataKey,
      refreshTokenPath: refreshTokenPath,
      removeAccessTokenBeforeRefresh: removeAccessTokenBeforeRefresh,
      refreshTokenContentType: refreshTokenContentType,
      allowCrossOriginRequests: allowCrossOriginRequests,
      sensitiveHeaders: Set<String>.unmodifiable(sensitive),
      logResponseBodies: logResponseBodies,
      sensitiveQueryParameters: Set<String>.unmodifiable(sensitiveQuery),
      internetStatusSubscription: internetStatusStream?.listen(
        (event) => _internetEnabled = event,
      ),
    );
  }

  @override
  late final NetKitParams parameters;

  @override
  late final NetKitTransport transport;

  late final bool _ownsTransport;

  @override
  late final NetKitErrorParams _errorParams;

  @override
  late final INetKitLogger _logger;

  @override
  late final Converter _converter;

  /// Updated from `internetStatusStream`; requests fail fast when false.
  @override
  bool _internetEnabled = true;

  @override
  Future<R> requestModel<R extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    MapType? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onReceiveProgress,
    NetKitProgressCallback? onSendProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    String? idempotencyKey,
    bool useDataKey = true,
  }) {
    _logger.debug(
      'Requesting model: $R at path: ${_logPath(path)} with method: $method',
    );
    return _execute(
      _call(
        path: path,
        method: method,
        body: body,
        headers: headers,
        queryParameters: queryParameters,
        timeout: timeout,
        cancellationToken: cancellationToken,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
        authPolicy: authPolicy,
        allowRetryOn401: allowRetryOn401,
        idempotencyKey: idempotencyKey,
      ),
      (outcome) {
        _logResponse(path, outcome);
        return _decodeModel(outcome, model, useDataKey: useDataKey);
      },
    );
  }

  @override
  Future<ApiMetaResponse<R, M>>
      requestModelMeta<R extends INetKitModel, M extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    required M metadataModel,
    MapType? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onReceiveProgress,
    NetKitProgressCallback? onSendProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    String? idempotencyKey,
    bool useDataKey = true,
  }) {
    return _execute(
      _call(
        path: path,
        method: method,
        body: body,
        headers: headers,
        queryParameters: queryParameters,
        timeout: timeout,
        cancellationToken: cancellationToken,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
        authPolicy: authPolicy,
        allowRetryOn401: allowRetryOn401,
        idempotencyKey: idempotencyKey,
      ),
      (outcome) {
        if (_hasEmptyResponseBody(outcome)) {
          throw _emptyResponseBodyError(outcome);
        }
        final split = _splitMetaResponse(
          outcome.data! as MapType,
          useDataKey: useDataKey,
        );
        return ApiMetaResponse(
          data: _converter.toModel<R>(split.data as MapType, model),
          metadata: _converter.toModel<M>(split.metadata, metadataModel),
        );
      },
    );
  }

  @override
  Future<List<R>> requestList<R extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    MapType? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onReceiveProgress,
    NetKitProgressCallback? onSendProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    String? idempotencyKey,
    bool useDataKey = true,
  }) {
    _logger.debug(
      'Requesting list of model: $R at path: ${_logPath(path)} '
      'with method: $method',
    );
    return _execute(
      _call(
        path: path,
        method: method,
        body: body,
        headers: headers,
        queryParameters: queryParameters,
        timeout: timeout,
        cancellationToken: cancellationToken,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
        authPolicy: authPolicy,
        allowRetryOn401: allowRetryOn401,
        idempotencyKey: idempotencyKey,
      ),
      (outcome) {
        _logResponse(path, outcome);
        if (_hasEmptyResponseBody(outcome)) {
          throw _emptyResponseBodyError(outcome);
        }
        return _converter.toListModel(
          data: _unwrapData(outcome.data, useDataKey: useDataKey),
          parsingModel: model,
        );
      },
    );
  }

  @override
  Future<ApiMetaResponse<List<R>, M>>
      requestListMeta<R extends INetKitModel, M extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    required M metadataModel,
    MapType? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onReceiveProgress,
    NetKitProgressCallback? onSendProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    String? idempotencyKey,
    bool useDataKey = true,
  }) {
    return _execute(
      _call(
        path: path,
        method: method,
        body: body,
        headers: headers,
        queryParameters: queryParameters,
        timeout: timeout,
        cancellationToken: cancellationToken,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
        authPolicy: authPolicy,
        allowRetryOn401: allowRetryOn401,
        idempotencyKey: idempotencyKey,
      ),
      (outcome) {
        if (_hasEmptyResponseBody(outcome)) {
          throw _emptyResponseBodyError(outcome);
        }
        final split = _splitMetaResponse(
          outcome.data! as MapType,
          useDataKey: useDataKey,
        );
        return ApiMetaResponse(
          data: _converter.toListModel(data: split.data, parsingModel: model),
          metadata: _converter.toModel<M>(split.metadata, metadataModel),
        );
      },
    );
  }

  @override
  Future<void> requestVoid({
    required String path,
    required RequestMethod method,
    MapType? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onReceiveProgress,
    NetKitProgressCallback? onSendProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    String? idempotencyKey,
  }) {
    return _execute(
      _call(
        path: path,
        method: method,
        body: body,
        headers: headers,
        queryParameters: queryParameters,
        timeout: timeout,
        cancellationToken: cancellationToken,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
        authPolicy: authPolicy,
        allowRetryOn401: allowRetryOn401,
        idempotencyKey: idempotencyKey,
      ),
      (_) {},
    );
  }

  @override
  Future<R> uploadMultipartData<R extends INetKitModel>({
    required String path,
    required R model,
    required NetKitMultipartFile multipartFile,
    required RequestMethod method,
    String fieldName = 'file',
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onSendProgress,
    NetKitProgressCallback? onReceiveProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    bool useDataKey = true,
  }) {
    return uploadFormData(
      path: path,
      model: model,
      formData: NetKitFormData(files: [MapEntry(fieldName, multipartFile)]),
      method: method,
      headers: headers,
      queryParameters: queryParameters,
      timeout: timeout,
      cancellationToken: cancellationToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      authPolicy: authPolicy,
      allowRetryOn401: allowRetryOn401,
      useDataKey: useDataKey,
    );
  }

  @override
  Future<R> uploadFormData<R extends INetKitModel>({
    required String path,
    required R model,
    required NetKitFormData formData,
    required RequestMethod method,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onSendProgress,
    NetKitProgressCallback? onReceiveProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    bool useDataKey = true,
  }) {
    return _upload(
      path: path,
      model: model,
      body: formData,
      method: method,
      // The transport sets the multipart content type with its boundary.
      contentType: null,
      headers: headers,
      queryParameters: queryParameters,
      timeout: timeout,
      cancellationToken: cancellationToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      authPolicy: authPolicy,
      allowRetryOn401: allowRetryOn401,
      useDataKey: useDataKey,
    );
  }

  @override
  Future<R> uploadRawData<R extends INetKitModel>({
    required String path,
    required R model,
    required List<int> data,
    required RequestMethod method,
    String contentType = 'application/octet-stream',
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onSendProgress,
    NetKitProgressCallback? onReceiveProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    bool useDataKey = true,
  }) {
    return _upload(
      path: path,
      model: model,
      body: BytesRawHttpBody(data),
      method: method,
      contentType: contentType,
      headers: headers,
      queryParameters: queryParameters,
      timeout: timeout,
      cancellationToken: cancellationToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      authPolicy: authPolicy,
      allowRetryOn401: allowRetryOn401,
      useDataKey: useDataKey,
    );
  }

  @override
  Future<R> uploadFile<R extends INetKitModel>({
    required String path,
    required R model,
    required String filePath,
    required RequestMethod method,
    String contentType = 'application/octet-stream',
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onSendProgress,
    NetKitProgressCallback? onReceiveProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    bool useDataKey = true,
  }) {
    return _upload(
      path: path,
      model: model,
      body: FileRawHttpBody(filePath),
      method: method,
      contentType: contentType,
      headers: headers,
      queryParameters: queryParameters,
      timeout: timeout,
      cancellationToken: cancellationToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      authPolicy: authPolicy,
      allowRetryOn401: allowRetryOn401,
      useDataKey: useDataKey,
    );
  }

  @override
  Map<String, String> getAllHeaders() => parameters.headers;

  @override
  void addHeader(MapEntry<String, String> mapEntry) {
    _credentialsChanged();
    RequestManagerMixin._putHeader(
      parameters.headers,
      mapEntry.key,
      mapEntry.value,
    );
  }

  @override
  void clearAllHeaders() {
    _credentialsChanged();
    parameters.headers.clear();
  }

  @override
  void removeHeader(String key) {
    _credentialsChanged();
    RequestManagerMixin._removeHeader(parameters.headers, key);
  }

  @override
  void dispose() {
    if (_ownsTransport) {
      transport.close(force: true);
    }
    parameters.internetStatusSubscription?.cancel();
  }

  @override
  void setAccessToken(String? token) {
    if (token == null) return;
    _credentialsChanged();
    _setAccessToken(token);
  }

  @override
  void setRefreshToken(String? token) {
    if (token == null) return;
    _credentialsChanged();
    _setRefreshToken(token);
  }

  @override
  void removeRefreshToken() {
    _credentialsChanged();
    _removeRefreshToken();
  }

  @override
  void removeAccessToken() {
    _credentialsChanged();
    _removeAccessToken();
  }

  /// Builds the internal call for a JSON request method.
  _Call _call({
    required String path,
    required RequestMethod method,
    required MapType? body,
    required Map<String, String>? headers,
    required Map<String, dynamic>? queryParameters,
    required NetKitTimeout? timeout,
    required NetKitCancellationToken? cancellationToken,
    required NetKitProgressCallback? onReceiveProgress,
    required NetKitProgressCallback? onSendProgress,
    required AuthPolicy authPolicy,
    required bool allowRetryOn401,
    required String? idempotencyKey,
  }) {
    final (encoded, contentType) = _encodeBody(
      body,
      RequestManagerMixin._headerValue(headers, 'content-type'),
    );
    return _Call(
      path: path,
      method: method.name.toUpperCase(),
      body: encoded,
      contentType: contentType,
      headers: headers,
      queryParameters: queryParameters,
      timeout: timeout,
      cancellationToken: cancellationToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      authPolicy: authPolicy,
      allowRetryOn401: allowRetryOn401,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Splits a meta response into payload data and metadata without mutating
  /// the original response map.
  ({dynamic data, MapType metadata}) _splitMetaResponse(
    MapType responseData, {
    required bool useDataKey,
  }) {
    final container = useDataKey && parameters.dataKey != null
        ? responseData[parameters.dataKey] as MapType
        : responseData;

    final copy = Map<String, dynamic>.from(container);
    final data = copy.remove(parameters.metadataDataKey);
    return (data: data, metadata: copy);
  }
}
