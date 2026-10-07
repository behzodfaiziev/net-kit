import 'dart:async';
import 'dart:typed_data';

import 'package:net_kit/net_kit.dart';
import 'package:net_kit/net_kit_dio.dart';
import 'package:test/test.dart';

import '../../mocks/recording_http_client_adapter.dart';

/// Lazily generated payload. Chunks are produced only when pulled, so the
/// number of produced chunks shows how much of the payload NetKit and Dio
/// hold at any time.
class _SyntheticPayload {
  _SyntheticPayload({required this.chunkSize, required this.chunkCount});

  final int chunkSize;
  final int chunkCount;
  int produced = 0;

  int get contentLength => chunkSize * chunkCount;

  Stream<List<int>> stream() async* {
    for (var i = 0; i < chunkCount; i++) {
      produced++;
      yield Uint8List(chunkSize)..fillRange(0, chunkSize, i & 0xff);
    }
  }
}

void main() {
  late RecordingHttpClientAdapter adapter;
  late DioNetKitTransport client;

  setUp(() {
    adapter = RecordingHttpClientAdapter()..drainStream = true;
    client = DioNetKitTransport(httpClientAdapter: adapter);
  });

  tearDown(() {
    client.close();
  });

  group('StreamRawHttpBody streaming', () {
    // 64 MiB declared, generated one 64 KiB chunk at a time.
    _SyntheticPayload payload() =>
        _SyntheticPayload(chunkSize: 64 * 1024, chunkCount: 1024);

    test('consumes the payload incrementally without materializing it',
        () async {
      final source = payload();
      final stream = source.stream();
      var maxLag = 0;
      adapter.onChunk = (_) async {
        final lag = source.produced - adapter.consumedChunks;
        if (lag > maxLag) {
          maxLag = lag;
        }
        await Future<void>.delayed(Duration.zero);
      };

      await client.send(
        RawHttpRequest(
          uri: Uri.parse('https://storage.example.com/object'),
          method: RawHttpMethod.put,
          body: StreamRawHttpBody(
            stream: stream,
            contentLength: source.contentLength,
          ),
        ),
      );

      expect(adapter.lastData, same(stream));
      expect(adapter.lastData, isNot(isA<List<int>>()));
      expect(adapter.lastData, isNot(isA<FormData>()));
      expect(adapter.consumedBytes, source.contentLength);
      expect(adapter.consumedChunks, source.chunkCount);
      expect(source.produced, source.chunkCount);
      // Pull-based: at most one chunk ahead of the adapter at any time.
      expect(maxLag, lessThanOrEqualTo(1));
    });

    test('sends the declared Content-Length and nothing else from the body',
        () async {
      final source = payload();

      await client.send(
        RawHttpRequest(
          uri: Uri.parse('https://storage.example.com/object'),
          method: RawHttpMethod.put,
          headers: const {'Content-Type': 'application/octet-stream'},
          body: StreamRawHttpBody(
            stream: source.stream(),
            contentLength: source.contentLength,
          ),
        ),
      );

      final headers = adapter.lastOptions!.headers;
      expect(headers['content-length'].toString(), '${source.contentLength}');
      expect(headers['content-type'], 'application/octet-stream');
      expect(headers.keys.map((k) => k.toLowerCase()).toSet(), {
        'content-length',
        'content-type',
      });
    });

    test('emits monotonic progress up to the declared length', () async {
      final source = payload();
      final progress = <(int, int)>[];

      await client.send(
        RawHttpRequest(
          uri: Uri.parse('https://storage.example.com/object'),
          method: RawHttpMethod.put,
          body: StreamRawHttpBody(
            stream: source.stream(),
            contentLength: source.contentLength,
          ),
          onSendProgress: (sent, total) => progress.add((sent, total)),
        ),
      );

      expect(progress, isNotEmpty);
      expect(progress.last.$1, source.contentLength);
      expect(progress.every((p) => p.$2 == source.contentLength), isTrue);
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i].$1, greaterThanOrEqualTo(progress[i - 1].$1));
      }
    });

    test('cancellation interrupts transmission before the payload ends',
        () async {
      final source = payload();
      final token = NetKitCancellationToken();
      const cancelAfterChunks = 10;
      adapter.onChunk = (_) async {
        if (adapter.consumedChunks == cancelAfterChunks) {
          token.cancel();
        }
        await Future<void>.delayed(Duration.zero);
      };

      await expectLater(
        client.send(
          RawHttpRequest(
            uri: Uri.parse('https://storage.example.com/object'),
            method: RawHttpMethod.put,
            body: StreamRawHttpBody(
              stream: source.stream(),
              contentLength: source.contentLength,
            ),
            cancellationToken: token,
          ),
        ),
        throwsA(
          isA<RawHttpException>().having(
            (error) => error.type,
            'type',
            RawHttpFailureType.cancellation,
          ),
        ),
      );

      // Let the adapter observe the cancellation and stop pulling.
      await Future<void>.delayed(Duration.zero);
      expect(adapter.consumedChunks, lessThan(source.chunkCount));
      expect(source.produced, lessThan(source.chunkCount));
      expect(adapter.consumedChunks, greaterThanOrEqualTo(cancelAfterChunks));
    });
  });
}
