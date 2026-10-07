import 'dart:io';
import 'dart:typed_data';

import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/core/net_kit_cancellation_token.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

/// Swaps the outgoing body so the transport sees a bare replayable stream.
class _BodySwap extends NetKitInterceptor {
  const _BodySwap(this.body);

  final RawHttpBody body;

  @override
  RawHttpRequest onRequest(RawHttpRequest request) =>
      request.copyWith(body: body);
}

/// Uploads are replayable bodies: streamed, never buffered, and re-opened
/// for the retry that follows a token refresh.
void main() {
  const chunkSize = 64 * 1024;
  const largeSize = 128 * 1024 * 1024;

  late FakeTransport transport;
  late Directory dir;
  late File file;
  late List<int> fileBytes;
  var refreshCalls = 0;

  NetKitManager build({List<NetKitInterceptor> interceptors = const []}) {
    final manager = NetKitManager(
      baseUrl: 'https://api.example.com',
      transport: transport,
      refreshTokenPath: '/auth/refresh',
      interceptors: interceptors,
    )
      ..setAccessToken('old-token')
      ..setRefreshToken('refresh-token');
    addTearDown(manager.dispose);
    return manager;
  }

  /// `/upload` answers `401` until the request carries the new token.
  void scriptUploadWithRefresh() {
    transport
      ..on(null, '/upload', (request, _) {
        if (request.headers['Authorization'] == 'Bearer new-token') {
          return FakeTransport.jsonResponse(200, {'ok': true});
        }
        return FakeTransport.jsonResponse(401, {'message': 'expired'});
      })
      ..on(RawHttpMethod.post, '/auth/refresh', (_, __) {
        refreshCalls++;
        return FakeTransport.jsonResponse(200, {'accessToken': 'new-token'});
      });
  }

  Iterable<int> uploadIndexes() => [
        for (var i = 0; i < transport.requests.length; i++)
          if (transport.requests[i].uri.path == '/upload') i,
      ];

  setUp(() async {
    refreshCalls = 0;
    transport = FakeTransport()
      ..fallback = (_) => FakeTransport.jsonResponse(200, null);
    dir = await Directory.systemTemp.createTemp('net_kit_replay');
    file = File('${dir.path}/blob.bin');
    fileBytes = List<int>.generate(300 * 1024, (i) => (i * 7) % 256);
    await file.writeAsBytes(fileBytes, flush: true);
  });

  tearDown(() => dir.delete(recursive: true));

  test('uploadFile hands the transport a FileRawHttpBody', () async {
    await build().uploadFile<VoidModel>(
      path: '/upload',
      model: VoidModel(),
      filePath: file.path,
      method: RequestMethod.put,
    );

    final body = transport.lastRequest!.body;
    expect(body, isA<FileRawHttpBody>());
    expect(body, isNot(isA<BytesRawHttpBody>()));
    expect((body! as FileRawHttpBody).path, file.path);
    expect(transport.lastBody, fileBytes);
  });

  test('uploadFile is re-opened in full for the retry after refresh', () async {
    scriptUploadWithRefresh();

    await build().uploadFile<VoidModel>(
      path: '/upload',
      model: VoidModel(),
      filePath: file.path,
      method: RequestMethod.put,
    );

    expect(refreshCalls, 1);
    final indexes = uploadIndexes().toList();
    expect(indexes, hasLength(2));
    for (final i in indexes) {
      expect(transport.requests[i].body, isA<FileRawHttpBody>());
      expect(transport.bodies[i], fileBytes);
    }
  });

  test('uploadFormData with a file part retries fully after refresh', () async {
    scriptUploadWithRefresh();
    final part = await NetKitMultipartFile.fromPath(file.path);

    await build().uploadFormData<VoidModel>(
      path: '/upload',
      model: VoidModel(),
      formData: NetKitFormData(
        fields: const [MapEntry('kind', 'blob')],
        files: [MapEntry('file', part)],
      ),
      method: RequestMethod.post,
      allowRetryOn401: true,
    );

    expect(refreshCalls, 1);
    final indexes = uploadIndexes().toList();
    expect(indexes, hasLength(2));
    final first = transport.bodies[indexes[0]]!;
    final second = transport.bodies[indexes[1]]!;
    expect(second, first);
    expect(first.length, greaterThan(fileBytes.length));
    final fileStart = first.length - fileBytes.length - 1;
    expect(first.sublist(fileStart, first.length - 1), fileBytes);
  });

  test('a 128 MiB logical upload streams without being buffered', () async {
    final chunk = Uint8List(chunkSize);
    Stream<List<int>> open() async* {
      for (var sent = 0; sent < largeSize; sent += chunkSize) {
        yield chunk;
      }
    }

    transport.materializeBodies = false;
    final manager = build(
      interceptors: [
        _BodySwap(ReplayableRawHttpBody(open: open, contentLength: largeSize)),
      ],
    );

    await manager.uploadFormData<VoidModel>(
      path: '/upload',
      model: VoidModel(),
      formData: NetKitFormData(
        files: [
          MapEntry(
            'file',
            NetKitMultipartFile.fromStream(open, largeSize),
          ),
        ],
      ),
      method: RequestMethod.put,
    );

    expect(transport.lastRequest!.body, isA<ReplayableRawHttpBody>());
    expect(transport.bodyLengths.last, largeSize);
    expect(transport.maxChunkLength, chunkSize);
    expect(transport.lastBody, isEmpty);
  });

  test('cancelling mid-upload yields a cancelled error and unbinds', () async {
    transport.waitForCancel = true;
    final token = NetKitCancellationToken();

    final upload = build().uploadFile<VoidModel>(
      path: '/upload',
      model: VoidModel(),
      filePath: file.path,
      method: RequestMethod.put,
      cancellationToken: token,
    );
    await transport.started.future;
    expect(netKitCancellationBindingCount(token), 1);
    token.cancel();

    await expectLater(
      upload,
      throwsA(
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiFailureType.cancelled)
            .having((e) => e.statusCode, 'statusCode', isNull),
      ),
    );
    expect(netKitCancellationBindingCount(token), 0);
  });

  test('onSendProgress is forwarded to the transport request', () async {
    await build().uploadFile<VoidModel>(
      path: '/upload',
      model: VoidModel(),
      filePath: file.path,
      method: RequestMethod.put,
      onSendProgress: (_, __) {},
    );

    expect(transport.lastRequest!.onSendProgress, isNotNull);
  });
}
