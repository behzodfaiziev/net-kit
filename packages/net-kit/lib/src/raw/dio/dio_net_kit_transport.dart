import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/net_kit_cancellation_token.dart';
import '../net_kit_transport.dart';
import '../raw_http_body.dart';
import '../raw_http_exception.dart';
import '../raw_http_method.dart';
import '../raw_http_request.dart';
import '../raw_http_response.dart';
import '../raw_http_streamed_response.dart';
import 'adapter/platform_http_adapter.dart';

/// Alias kept for raw-transport code written against 5.5.
typedef DioRawHttpClient = DioNetKitTransport;

/// [NetKitTransport] backed by a private Dio instance.
///
/// This is the default transport of `NetKitManager` and the built-in
/// `RawHttpClient`. The Dio instance has no interceptors, accepts every
/// status code, never follows redirects unless the request asks for it, and
/// never implies a content type. Dio exceptions are converted to
/// [RawHttpException]; Dio types do not appear in the transport contract.
///
/// Import `package:net_kit/net_kit_dio.dart` to construct it; application
/// code should depend on [NetKitTransport] / `RawHttpClient` and choose the
/// implementation only at the composition root.
final class DioNetKitTransport implements NetKitTransport {
  /// Creates a transport over a new Dio instance.
  ///
  /// [httpClientAdapter] replaces the platform default adapter, for example
  /// to configure a proxy or certificates, or to inject a fake in tests.
  /// [browserWithCredentials] applies to the web adapter only and controls
  /// whether cross-site requests carry cookies; keep it `false` for
  /// transports that talk to third-party hosts.
  DioNetKitTransport({
    HttpClientAdapter? httpClientAdapter,
    bool browserWithCredentials = false,
  }) : _dio = _createDio(
          httpClientAdapter ??
              createPlatformAdapter(withCredentials: browserWithCredentials)
                  .getAdapter(),
        );

  final Dio _dio;

  /// The owned Dio instance, for adapter-level configuration or Dio-based
  /// test doubles. Do not add interceptors that change status handling.
  Dio get dio => _dio;

  /// Known Dio failure kinds. Values added by newer Dio releases are
  /// classified by [_failureType] without a compile-time dependency, so a
  /// Dio upgrade cannot break this transport.
  static const Map<DioExceptionType, RawHttpFailureType> _failureTypes = {
    DioExceptionType.connectionTimeout: RawHttpFailureType.timeout,
    DioExceptionType.sendTimeout: RawHttpFailureType.timeout,
    DioExceptionType.receiveTimeout: RawHttpFailureType.timeout,
    DioExceptionType.connectionError: RawHttpFailureType.connection,
    DioExceptionType.badCertificate: RawHttpFailureType.tls,
    DioExceptionType.cancel: RawHttpFailureType.cancellation,
    DioExceptionType.badResponse: RawHttpFailureType.invalidResponse,
    DioExceptionType.unknown: RawHttpFailureType.unknown,
  };

  static Dio _createDio(HttpClientAdapter httpClientAdapter) {
    final dio = Dio(
      BaseOptions(
        validateStatus: (_) => true,
        followRedirects: false,
        responseType: ResponseType.bytes,
      ),
    );
    dio.interceptors.removeImplyContentTypeInterceptor();
    dio.httpClientAdapter = httpClientAdapter;
    return dio;
  }

  @override
  Future<RawHttpResponse> send(RawHttpRequest request) async {
    final binding = _Binding(request.cancellationToken);
    try {
      final options = await _compose(request, binding, ResponseType.bytes);
      final response = await _dio.fetch<Object>(options);
      final statusCode = _requireStatus(response, request.uri);
      final data = response.data;
      return RawHttpResponse(
        statusCode: statusCode,
        headers: _copyHeaders(response.headers.map),
        bodyBytes: data is List<int> ? data : const [],
        redirected: _followedRedirect(
          statusCode,
          isRedirect: response.isRedirect,
          redirectCount: response.redirects.length,
        ),
      );
    } on DioException catch (error) {
      throw _toRawException(error, request.uri);
    } finally {
      binding.release();
    }
  }

  /// Streams the response without going through `Dio.fetch`.
  ///
  /// Dio re-emits adapter streams through a controller that never pauses the
  /// socket, so a slow consumer would make Dio buffer the whole body. Calling
  /// the [HttpClientAdapter] directly keeps the HTTP client's own stream, and
  /// `async*` in [_guardBody] propagates the consumer's pauses to it.
  @override
  Future<RawHttpStreamedResponse> sendStreamed(RawHttpRequest request) async {
    final binding = _Binding(request.cancellationToken);
    try {
      final options = await _compose(request, binding, ResponseType.stream);
      final body = await _dio.httpClientAdapter.fetch(
        options,
        _requestStream(options, request),
        binding.cancelToken?.whenCancel,
      );
      var stream = body.stream;
      final receive = request.timeout?.receive;
      if (receive != null) {
        stream = stream.timeout(
          receive,
          onTimeout: (sink) => sink
            ..addError(
              RawHttpException(
                message: 'Receiving the response timed out',
                type: RawHttpFailureType.timeout,
                uri: request.uri,
              ),
            )
            ..close(),
        );
      }
      return RawHttpStreamedResponse(
        statusCode: body.statusCode,
        headers: _copyHeaders(body.headers),
        body: _guardBody(stream, request, binding),
        redirected: _followedRedirect(
          body.statusCode,
          isRedirect: body.isRedirect,
          redirectCount: body.redirects?.length ?? 0,
        ),
      );
    } on DioException catch (error) {
      binding.release();
      throw _toRawException(error, request.uri);
    } on RawHttpException {
      binding.release();
      rethrow;
    } on Object catch (error) {
      binding.release();
      throw _toRawFromUnknown(error, request);
    }
  }

  /// Converts the composed body into the adapter's request stream and
  /// reports upload progress, mirroring what `Dio.fetch` does internally.
  Stream<Uint8List>? _requestStream(
    RequestOptions options,
    RawHttpRequest request,
  ) {
    final data = options.data;
    Stream<List<int>> stream;
    switch (data) {
      case null:
        return null;
      case FormData():
        options.headers[Headers.contentTypeHeader] =
            'multipart/form-data; boundary=${data.boundary}';
        options.headers[Headers.contentLengthHeader] = '${data.length}';
        stream = data.finalize();
      case Stream<List<int>>():
        stream = data;
      case List<int>():
        stream = Stream.value(data);
      case String():
        final bytes = utf8.encode(data);
        _setHeader(
          options.headers.cast<String, String>(),
          Headers.contentLengthHeader,
          '${bytes.length}',
        );
        stream = Stream.value(bytes);
      default:
        throw ArgumentError.value(data, 'body', 'Unsupported body');
    }

    final onSendProgress = request.onSendProgress;
    final total = int.tryParse(
          '${options.headers[Headers.contentLengthHeader] ?? ''}',
        ) ??
        -1;
    var sent = 0;
    return stream.map((chunk) {
      final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
      if (onSendProgress != null) {
        sent += bytes.length;
        onSendProgress(sent, total);
      }
      return bytes;
    });
  }

  /// Whether the HTTP client followed a redirect itself.
  ///
  /// `dart:io` lists followed hops in `redirects`, and flags an unfollowed
  /// `3xx` as `isRedirect` too, so a redirect status on its own is not a
  /// followed redirect. The browser adapter follows redirects
  /// unconditionally and only sets `isRedirect` when the final URL differs.
  static bool _followedRedirect(
    int statusCode, {
    required bool isRedirect,
    required int redirectCount,
  }) {
    if (redirectCount > 0) {
      return true;
    }
    return isRedirect && !_redirectStatuses.contains(statusCode);
  }

  static const Set<int> _redirectStatuses = {301, 302, 303, 307, 308};

  @override
  void close({bool force = false}) {
    _dio.close(force: force);
  }

  /// Wraps the Dio body stream so cancellation ends it with a raw exception,
  /// Dio errors are converted, and the token binding is released when the
  /// consumer is done. `async*` keeps the source paused while the consumer
  /// is not pulling, so back-pressure is preserved.
  Stream<List<int>> _guardBody(
    Stream<Uint8List> source,
    RawHttpRequest request,
    _Binding binding,
  ) async* {
    final token = request.cancellationToken;
    final onReceiveProgress = request.onReceiveProgress;
    var received = 0;
    try {
      await for (final chunk in source) {
        if (token?.isCancelled ?? false) {
          throw _cancelled(request.uri);
        }
        if (onReceiveProgress != null) {
          received += chunk.length;
          onReceiveProgress(received, -1);
        }
        yield chunk;
      }
      if (token?.isCancelled ?? false) {
        throw _cancelled(request.uri);
      }
    } on RawHttpException {
      rethrow;
    } on DioException catch (error) {
      throw _toRawException(error, request.uri);
    } on Object catch (error) {
      if (token?.isCancelled ?? false) {
        throw _cancelled(request.uri);
      }
      throw _toRawFromUnknown(error, request);
    } finally {
      binding.release();
    }
  }

  RawHttpException _toRawFromUnknown(Object error, RawHttpRequest request) {
    if (error is TimeoutException) {
      return RawHttpException(
        message: error.message ?? 'The request timed out',
        type: RawHttpFailureType.timeout,
        cause: error,
        uri: request.uri,
      );
    }
    return RawHttpException(
      message: error.toString(),
      type: RawHttpFailureType.unknown,
      cause: error,
      uri: request.uri,
    );
  }

  Future<RequestOptions> _compose(
    RawHttpRequest request,
    _Binding binding,
    ResponseType responseType,
  ) async {
    final headers = Map<String, String>.from(request.headers);
    final data = await _mapBody(request.body, headers);

    final options = Options(
      method: request.method.httpName,
      headers: headers,
      sendTimeout: request.timeout?.send,
      receiveTimeout: request.timeout?.receive,
      validateStatus: (_) => true,
      followRedirects: request.followRedirects,
      responseType: responseType,
    ).compose(
      _dio.options,
      request.uri.toString(),
      data: data,
      cancelToken: binding.cancelToken,
      onSendProgress: request.onSendProgress,
      onReceiveProgress: request.onReceiveProgress,
    );
    final connect = request.timeout?.connect;
    if (connect != null) {
      options.connectTimeout = connect;
    }
    return options;
  }

  int _requireStatus(Response<Object?> response, Uri uri) {
    final statusCode = response.statusCode;
    if (statusCode == null) {
      throw RawHttpException(
        message: 'Transport returned no HTTP status code',
        type: RawHttpFailureType.invalidResponse,
        uri: uri,
      );
    }
    return statusCode;
  }

  Future<Object?> _mapBody(
    RawHttpBody? body,
    Map<String, String> headers,
  ) async {
    switch (body) {
      case null:
        return null;
      case StreamRawHttpBody(:final stream, :final contentLength):
        _setHeader(headers, 'Content-Length', '$contentLength');
        return stream;
      case ReplayableRawHttpBody(:final open, :final contentLength):
        _setHeader(headers, 'Content-Length', '$contentLength');
        return open();
      case FileRawHttpBody():
        _setHeader(headers, 'Content-Length', '${await body.length()}');
        return body.openRead();
      case BytesRawHttpBody(:final bytes):
        _setHeader(headers, 'Content-Length', '${bytes.length}');
        return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      case StringRawHttpBody(:final value):
        return value;
      case NetKitFormData():
        // Dio sets the multipart content type with the boundary itself.
        headers.removeWhere((key, _) => key.toLowerCase() == 'content-type');
        return _toFormData(body);
    }
  }

  /// Builds a fresh Dio `FormData` for every send so the body is replayable
  /// and file parts stream from their factories.
  FormData _toFormData(NetKitFormData body) {
    final formData = FormData();
    formData.fields.addAll(body.fields);
    for (final entry in body.files) {
      final file = entry.value;
      formData.files.add(
        MapEntry(
          entry.key,
          MultipartFile.fromStream(
            file.open,
            file.length,
            filename: file.filename,
            contentType: file.contentType == null
                ? null
                : DioMediaType.parse(file.contentType!),
          ),
        ),
      );
    }
    return formData;
  }

  void _setHeader(Map<String, String> headers, String name, String value) {
    headers.removeWhere((key, _) => key.toLowerCase() == name.toLowerCase());
    headers[name] = value;
  }

  Map<String, List<String>> _copyHeaders(Map<String, List<String>> source) {
    return Map<String, List<String>>.unmodifiable({
      for (final entry in source.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    });
  }

  RawHttpException _cancelled(Uri uri) => RawHttpException(
        message: 'The request was cancelled',
        type: RawHttpFailureType.cancellation,
        uri: uri,
      );

  RawHttpException _toRawException(DioException error, Uri uri) {
    return RawHttpException(
      message: error.message ?? error.toString(),
      type: _failureType(error.type),
      cause: error,
      uri: uri,
    );
  }

  RawHttpFailureType _failureType(DioExceptionType type) {
    final known = _failureTypes[type];
    if (known != null) {
      return known;
    }
    // Dio 5.10 added `transformTimeout`; future releases may add more.
    return type.name.toLowerCase().endsWith('timeout')
        ? RawHttpFailureType.timeout
        : RawHttpFailureType.unknown;
  }
}

/// Pairs a Dio `CancelToken` with the caller's token for one request.
final class _Binding {
  _Binding(NetKitCancellationToken? token) {
    if (token == null) {
      return;
    }
    final dioToken = CancelToken();
    cancelToken = dioToken;
    _unbind = bindNetKitCancellationToken(token, dioToken.cancel);
  }

  CancelToken? cancelToken;
  void Function()? _unbind;

  /// Releases the token binding. Safe to call more than once.
  void release() {
    _unbind?.call();
    _unbind = null;
  }
}
