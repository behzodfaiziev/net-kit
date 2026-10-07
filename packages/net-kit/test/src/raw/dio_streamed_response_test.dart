import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:net_kit/net_kit.dart';
import 'package:net_kit/net_kit_dio.dart';
import 'package:net_kit/src/core/net_kit_cancellation_token.dart';
import 'package:test/test.dart';

import '../../mocks/recording_http_client_adapter.dart';

/// Pull-based response payload. Chunks are generated only when the stream is
/// pulled, so `produced - consumed` shows how many chunks sit in buffers
/// between the adapter and the consumer at any time.
class _SyntheticPayload {
  _SyntheticPayload({required this.chunkSize, required this.chunkCount});

  final int chunkSize;
  final int chunkCount;
  int produced = 0;

  int get contentLength => chunkSize * chunkCount;

  Stream<Uint8List> stream() async* {
    for (var i = 0; i < chunkCount; i++) {
      produced++;
      yield Uint8List(chunkSize)..fillRange(0, chunkSize, i & 0xff);
    }
  }
}

void main() {
  late RecordingHttpClientAdapter adapter;
  late DioNetKitTransport client;

  RawHttpRequest request({NetKitCancellationToken? token}) => RawHttpRequest(
        uri: Uri.parse('https://storage.example.com/objects/42'),
        method: RawHttpMethod.get,
        cancellationToken: token,
      );

  final isCancellation = isA<RawHttpException>().having(
    (error) => error.type,
    'type',
    RawHttpFailureType.cancellation,
  );

  setUp(() {
    adapter = RecordingHttpClientAdapter();
    client = DioNetKitTransport(httpClientAdapter: adapter);
  });

  tearDown(() {
    client.close();
  });

  group('DioNetKitTransport.sendStreamed', () {
    test('returns status and headers before the body completes', () async {
      final controller = StreamController<Uint8List>();
      adapter
        ..statusCode = 206
        ..responseHeaders = {
          'content-type': ['application/octet-stream'],
          'content-length': ['3'],
          'content-range': ['bytes 0-2/10'],
        }
        ..responseStream = controller.stream;

      final response = await client.sendStreamed(request());

      expect(response.statusCode, 206);
      expect(response.isSuccessful, isTrue);
      expect(response.header('Content-Type'), 'application/octet-stream');
      expect(response.contentLength, 3);
      expect(response.header('content-range'), 'bytes 0-2/10');
      expect(adapter.lastOptions!.responseType, ResponseType.stream);

      final collected = response.body.toList();
      controller.add(Uint8List.fromList([1, 2, 3]));
      await controller.close();
      expect((await collected).expand((c) => c), [1, 2, 3]);
    });

    // The transport reads the adapter stream directly (not through Dio's
    // response handler, which re-emits through an unpaused controller), so a
    // slow consumer pauses the pull-based producer: the number of chunks in
    // flight stays constant regardless of payload size.
    test('delivers the head of the body before the producer finishes',
        () async {
      final source = _SyntheticPayload(chunkSize: 1024, chunkCount: 64);
      adapter.responseStream = source.stream();
      var consumed = 0;
      var maxLag = 0;
      var producedAtFirstChunk = -1;

      final response = await client.sendStreamed(request());
      await for (final chunk in response.body) {
        consumed++;
        expect(chunk, hasLength(1024));
        if (consumed == 1) {
          producedAtFirstChunk = source.produced;
        }
        maxLag = max(maxLag, source.produced - consumed);
        // A slow consumer: yield to the event loop between chunks.
        await Future<void>.delayed(Duration.zero);
      }

      printOnFailure('max producer lag: $maxLag chunks');
      expect(consumed, source.chunkCount);
      expect(source.produced, source.chunkCount);
      expect(producedAtFirstChunk, lessThan(source.chunkCount));
      expect(maxLag, lessThanOrEqualTo(1));
    });

    test('streams a 64 MiB body chunk by chunk', () async {
      final source = _SyntheticPayload(chunkSize: 64 * 1024, chunkCount: 1024);
      adapter
        ..responseHeaders = {
          'content-length': ['${source.contentLength}'],
        }
        ..responseStream = source.stream();
      var received = 0;
      var consumed = 0;
      var maxLag = 0;
      var producedAtFirstChunk = -1;

      final response = await client.sendStreamed(request());
      expect(response.contentLength, source.contentLength);
      await for (final chunk in response.body) {
        consumed++;
        received += chunk.length;
        if (consumed == 1) {
          producedAtFirstChunk = source.produced;
        }
        maxLag = max(maxLag, source.produced - consumed);
      }

      printOnFailure('max producer lag: $maxLag chunks');
      expect(received, source.contentLength);
      expect(consumed, source.chunkCount);
      expect(producedAtFirstChunk, lessThan(source.chunkCount));
      expect(maxLag, lessThanOrEqualTo(1));
    });

    test('cancelling the token mid-stream ends the body with cancellation',
        () async {
      final source = _SyntheticPayload(chunkSize: 16, chunkCount: 100);
      adapter.responseStream = source.stream();
      final token = NetKitCancellationToken();
      var seen = 0;

      final response = await client.sendStreamed(request(token: token));
      expect(netKitCancellationBindingCount(token), 1);

      await expectLater(
        () async {
          await for (final _ in response.body) {
            if (++seen == 3) {
              token.cancel();
            }
            await Future<void>.delayed(Duration.zero);
          }
        }(),
        throwsA(isCancellation),
      );

      expect(seen, lessThan(source.chunkCount));
      expect(netKitCancellationBindingCount(token), 0);
    });

    test('consuming the body to completion releases the token binding',
        () async {
      adapter.responseBytes = utf8.encode('payload');
      final token = NetKitCancellationToken();

      final response = await client.sendStreamed(request(token: token));
      expect(netKitCancellationBindingCount(token), 1);

      final bytes = (await response.body.toList()).expand((c) => c).toList();

      expect(utf8.decode(bytes), 'payload');
      expect(netKitCancellationBindingCount(token), 0);
      expect(token.cancel, returnsNormally);
    });

    test('a 404 is returned as a streamed response, not thrown', () async {
      adapter
        ..statusCode = 404
        ..responseHeaders = {
          'content-type': ['application/json'],
        }
        ..responseBytes = utf8.encode('{"message":"Not found"}');

      final response = await client.sendStreamed(request());

      expect(response.statusCode, 404);
      expect(response.isSuccessful, isFalse);
      final bytes = (await response.body.toList()).expand((c) => c).toList();
      expect(utf8.decode(bytes), '{"message":"Not found"}');
    });

    test('a transport failure before the head is a RawHttpException', () async {
      adapter.throwType = DioExceptionType.connectionError;
      final token = NetKitCancellationToken();

      await expectLater(
        client.sendStreamed(request(token: token)),
        throwsA(
          isA<RawHttpException>().having(
            (error) => error.type,
            'type',
            RawHttpFailureType.connection,
          ),
        ),
      );
      expect(netKitCancellationBindingCount(token), 0);
    });

    test('send still buffers small responses into bodyBytes', () async {
      adapter.responseBytes = utf8.encode('{"ok":true}');

      final response = await client.send(request());

      expect(response, isA<RawHttpResponse>());
      expect(response.bodyText, '{"ok":true}');
      expect(response.bodyBytes, hasLength(11));
      expect(adapter.lastOptions!.responseType, ResponseType.bytes);
    });
  });
}
