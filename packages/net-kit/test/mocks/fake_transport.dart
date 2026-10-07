import 'dart:async';
import 'dart:convert';

import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/core/net_kit_cancellation_token.dart';

/// Handler for a scripted route. [body] is the fully read request body, or
/// `null` when the request had none.
typedef FakeRouteHandler = FutureOr<RawHttpResponse> Function(
  RawHttpRequest request,
  List<int>? body,
);

/// In-memory [NetKitTransport] with no Dio dependency.
///
/// Records every request it receives (with the materialized body), answers
/// from a route table keyed by method and path, and supports scripted
/// transport failures and cancellation. It proves `NetKitManager` depends on
/// the transport contract only.
class FakeTransport implements NetKitTransport {
  /// Every request in arrival order.
  final List<RawHttpRequest> requests = [];

  /// Materialized request bodies, parallel to [requests]. Entries are `null`
  /// for body-less requests, and empty when [materializeBodies] is false.
  final List<List<int>?> bodies = [];

  /// Number of body bytes read per request, parallel to [requests].
  final List<int> bodyLengths = [];

  /// Largest single chunk seen while reading a streamed body.
  int maxChunkLength = 0;

  /// When false, streamed bodies are counted but not kept, so large
  /// synthetic payloads can be sent without holding them in memory.
  bool materializeBodies = true;

  final List<_Route> _routes = [];

  /// Number of [close] calls.
  int closeCalls = 0;

  /// Reply for requests that match no route.
  RawHttpResponse Function(RawHttpRequest request) fallback =
      (_) => jsonResponse(404, {'message': 'Not found'});

  /// When set, the next [send] throws it instead of answering, then resets.
  RawHttpException? nextError;

  /// When true, a request with a cancellation token blocks until the token
  /// is cancelled and then fails with a cancellation error.
  bool waitForCancel = false;

  /// Completed when the first request arrives.
  final Completer<void> started = Completer<void>();

  /// Last request, or `null` when nothing was sent.
  RawHttpRequest? get lastRequest => requests.isEmpty ? null : requests.last;

  /// Last materialized body, or `null`.
  List<int>? get lastBody => bodies.isEmpty ? null : bodies.last;

  /// Registers a handler for [method] (any method when `null`) and [path].
  ///
  /// [path] is compared with the request's URI path, or with the full URL
  /// without query when it is absolute.
  void on(RawHttpMethod? method, String path, FakeRouteHandler handler) {
    _routes.add(_Route(method, path, handler));
  }

  /// Registers a JSON reply for `GET` [path].
  void onGet(String path, {int status = 200, Object? json, Headers? headers}) {
    on(
      RawHttpMethod.get,
      path,
      (_, __) => jsonResponse(status, json, headers),
    );
  }

  /// Registers a JSON reply for `POST` [path].
  void onPost(String path, {int status = 200, Object? json, Headers? headers}) {
    on(
      RawHttpMethod.post,
      path,
      (_, __) => jsonResponse(status, json, headers),
    );
  }

  /// Registers a JSON reply for `PUT` [path].
  void onPut(String path, {int status = 200, Object? json, Headers? headers}) {
    on(
      RawHttpMethod.put,
      path,
      (_, __) => jsonResponse(status, json, headers),
    );
  }

  /// Registers a JSON reply for `PATCH` [path].
  void onPatch(
    String path, {
    int status = 200,
    Object? json,
    Headers? headers,
  }) {
    on(
      RawHttpMethod.patch,
      path,
      (_, __) => jsonResponse(status, json, headers),
    );
  }

  /// Registers a JSON reply for `DELETE` [path].
  void onDelete(
    String path, {
    int status = 200,
    Object? json,
    Headers? headers,
  }) {
    on(
      RawHttpMethod.delete,
      path,
      (_, __) => jsonResponse(status, json, headers),
    );
  }

  /// Registers a reply for any method on [path].
  void onAny(String path, {int status = 200, Object? json, Headers? headers}) {
    on(null, path, (_, __) => jsonResponse(status, json, headers));
  }

  /// Builds a JSON response. A `null` [json] produces an empty body.
  static RawHttpResponse jsonResponse(
    int status,
    Object? json, [
    Headers? headers,
  ]) {
    return RawHttpResponse(
      statusCode: status,
      headers: {
        if (json != null) 'content-type': ['application/json; charset=utf-8'],
        ...?headers,
      },
      bodyBytes: json == null ? const [] : utf8.encode(jsonEncode(json)),
    );
  }

  /// Reads a body to bytes the way a transport would. Streams are consumed,
  /// replayable bodies are opened once, and multipart bodies are encoded as
  /// `name=value` lines followed by `name:filename:` plus the file bytes.
  static Future<List<int>?> readBody(RawHttpBody? body) async {
    switch (body) {
      case null:
        return null;
      case BytesRawHttpBody(:final bytes):
        return List<int>.of(bytes);
      case StringRawHttpBody(:final value):
        return utf8.encode(value);
      case StreamRawHttpBody(:final stream):
        return _collect(stream);
      case ReplayableRawHttpBody(:final open):
        return _collect(open());
      case FileRawHttpBody():
        return _collect(body.openRead());
      case NetKitFormData(:final fields, :final files):
        final out = <int>[];
        for (final field in fields) {
          out.addAll(utf8.encode('${field.key}=${field.value}\n'));
        }
        for (final file in files) {
          out
            ..addAll(utf8.encode('${file.key}:${file.value.filename ?? ''}:'))
            ..addAll(await _collect(file.value.open()))
            ..addAll(utf8.encode('\n'));
        }
        return out;
    }
  }

  /// Reads a body chunk by chunk, keeping only the byte count.
  Future<int> _count(RawHttpBody? body) async {
    final stream = switch (body) {
      null => null,
      StreamRawHttpBody(:final stream) => stream,
      ReplayableRawHttpBody(:final open) => open(),
      FileRawHttpBody() => body.openRead(),
      BytesRawHttpBody(:final bytes) => Stream.value(bytes),
      StringRawHttpBody(:final value) => Stream.value(utf8.encode(value)),
      NetKitFormData() => Stream.value(await readBody(body) ?? const []),
    };
    if (stream == null) {
      return 0;
    }
    var total = 0;
    await for (final chunk in stream) {
      total += chunk.length;
      if (chunk.length > maxChunkLength) {
        maxChunkLength = chunk.length;
      }
    }
    return total;
  }

  static Future<List<int>> _collect(Stream<List<int>> stream) async {
    final out = <int>[];
    await for (final chunk in stream) {
      out.addAll(chunk);
    }
    return out;
  }

  @override
  Future<RawHttpResponse> send(RawHttpRequest request) async {
    requests.add(request);
    if (materializeBodies) {
      final body = await readBody(request.body);
      bodies.add(body);
      bodyLengths.add(body?.length ?? 0);
    } else {
      bodies.add(request.body == null ? null : const []);
      bodyLengths.add(await _count(request.body));
    }
    if (!started.isCompleted) {
      started.complete();
    }

    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }

    final token = request.cancellationToken;
    if (token != null) {
      if (token.isCancelled) {
        throw _cancelled(request.uri);
      }
      if (waitForCancel) {
        final cancelled = Completer<void>();
        final unbind = bindNetKitCancellationToken(token, cancelled.complete);
        try {
          await cancelled.future;
        } finally {
          unbind();
        }
        throw _cancelled(request.uri);
      }
    }

    final route = _match(request);
    if (route == null) {
      return fallback(request);
    }
    return route.handler(request, bodies.last);
  }

  @override
  Future<RawHttpStreamedResponse> sendStreamed(RawHttpRequest request) async {
    final response = await send(request);
    return RawHttpStreamedResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: Stream<List<int>>.value(response.bodyBytes),
    );
  }

  @override
  void close({bool force = false}) {
    closeCalls++;
  }

  _Route? _match(RawHttpRequest request) {
    final full = request.uri.replace(query: '').toString().replaceAll(
          RegExp(r'\?$'),
          '',
        );
    for (final route in _routes.reversed) {
      if (route.method != null && route.method != request.method) {
        continue;
      }
      if (route.path == request.uri.path || route.path == full) {
        return route;
      }
    }
    return null;
  }

  static RawHttpException _cancelled(Uri uri) => RawHttpException(
        message: 'cancelled',
        type: RawHttpFailureType.cancellation,
        uri: uri,
      );
}

/// Response header map shorthand.
typedef Headers = Map<String, List<String>>;

class _Route {
  _Route(this.method, this.path, this.handler);

  final RawHttpMethod? method;
  final String path;
  final FakeRouteHandler handler;
}
