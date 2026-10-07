import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// In-memory [HttpClientAdapter] that records every request it receives.
///
/// Used by raw transport and manager tests. It never touches the network.
class RecordingHttpClientAdapter implements HttpClientAdapter {
  /// Every request in arrival order.
  final List<RequestOptions> requests = [];

  /// Dio-wrapped request stream of the last request, if any.
  Stream<Uint8List>? lastRequestStream;

  /// `RequestOptions.data` of the last request.
  Object? lastData;

  /// Status code to answer with.
  int statusCode = 200;

  /// Headers to answer with.
  Map<String, List<String>> responseHeaders = {};

  /// Body bytes to answer with.
  List<int> responseBytes = const [];

  /// When set, the adapter answers with this stream instead of
  /// [responseBytes]. It is handed to Dio as-is, so tests can observe how far
  /// ahead of the consumer a pull-based producer runs.
  Stream<Uint8List>? responseStream;

  /// Reported as `ResponseBody.isRedirect`, as the browser adapter does when
  /// the platform followed a redirect on its own.
  bool responseIsRedirect = false;

  /// Reported as `ResponseBody.redirects`, as the `dart:io` adapter does for
  /// redirects it followed.
  List<RedirectRecord>? responseRedirects;

  /// When set, the adapter throws a [DioException] of this type instead of
  /// answering.
  DioExceptionType? throwType;

  /// Completed when the first request reaches the adapter.
  Completer<void>? started;

  /// Block until the request is cancelled before answering.
  bool waitForCancel = false;

  /// Consume the request stream chunk by chunk before answering.
  bool drainStream = false;

  /// Keep the consumed request bytes in [bodyBytes] (tests with small bodies).
  bool collectBody = false;

  /// Awaited after each consumed chunk while draining.
  Future<void> Function(Uint8List chunk)? onChunk;

  /// Bytes consumed from the request stream so far.
  int consumedBytes = 0;

  /// Chunks consumed from the request stream so far.
  int consumedChunks = 0;

  /// Collected request body when [collectBody] is true.
  final List<int> bodyBytes = [];

  /// Number of [close] calls.
  int closeCalls = 0;

  /// Last request, or `null` when nothing was sent.
  RequestOptions? get lastOptions => requests.isEmpty ? null : requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    lastRequestStream = requestStream;
    lastData = options.data;
    if (started != null && !started!.isCompleted) {
      started!.complete();
    }

    var cancelled = false;
    unawaited(cancelFuture?.whenComplete(() => cancelled = true));

    if (waitForCancel && cancelFuture != null) {
      await cancelFuture;
    }

    if (drainStream && requestStream != null) {
      await for (final chunk in requestStream) {
        if (cancelled) {
          break;
        }
        consumedChunks++;
        consumedBytes += chunk.length;
        if (collectBody) {
          bodyBytes.addAll(chunk);
        }
        if (onChunk != null) {
          await onChunk!(chunk);
        }
        if (cancelled) {
          break;
        }
      }
      if (cancelled) {
        // A real adapter aborts the socket here. Dio has already surfaced
        // the cancellation to the caller, so this value is discarded.
        return ResponseBody.fromBytes(<int>[], 499);
      }
    }

    if (throwType != null) {
      throw DioException(
        requestOptions: options,
        type: throwType!,
        message: throwType!.name,
      );
    }

    final stream = responseStream;
    if (stream != null) {
      return ResponseBody(
        stream,
        statusCode,
        headers: responseHeaders,
        isRedirect: responseIsRedirect,
        redirects: responseRedirects,
      );
    }
    return ResponseBody.fromBytes(
      responseBytes,
      statusCode,
      headers: responseHeaders,
      isRedirect: responseIsRedirect,
    )..redirects = responseRedirects;
  }

  @override
  void close({bool force = false}) {
    closeCalls++;
  }
}
