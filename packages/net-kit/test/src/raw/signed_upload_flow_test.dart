import 'dart:io';
import 'dart:math';

import 'package:net_kit/net_kit.dart';
import 'package:net_kit/net_kit_dio.dart';
import 'package:test/test.dart';

import '../../mocks/fake_transport.dart';
import '../../mocks/recording_http_client_adapter.dart';

/// Signed-URL response model returned by the API.
class _SignedUploadModel extends INetKitModel {
  const _SignedUploadModel({this.url, this.headers = const {}});

  final String? url;
  final Map<String, String> headers;

  @override
  _SignedUploadModel fromJson(Map<String, dynamic> json) {
    return _SignedUploadModel(
      url: json['url'] as String?,
      headers: (json['headers'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v.toString())),
    );
  }

  @override
  Map<String, dynamic>? toJson() => {'url': url, 'headers': headers};
}

/// Signed object-storage upload: an authenticated API call returns a signed
/// PUT URL, then the file is streamed from disk straight to that URL through
/// [RawHttpClient] without the API access token and without token refresh.
void main() {
  const signedUrl =
      'https://storage.example.com/example-bucket/uploads/42/report.pdf'
      '?X-Algorithm=HMAC-SHA256'
      '&X-Credential=uploader%40example-project'
      '%2F20261007%2Fauto%2Fstorage%2Fsigned_request'
      '&X-Date=20261007T101500Z&X-Expires=600'
      '&X-SignedHeaders=content-type%3Bhost'
      '&X-Signature=9f8e7d6c5b4a';

  late Directory tempDir;
  late File file;
  late List<int> fileBytes;
  late NetKitManager manager;
  late FakeTransport api;
  late RecordingHttpClientAdapter storageAdapter;
  late DioNetKitTransport storage;
  var sessionInvalidations = 0;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('net_kit_signed_upload');
    file = File('${tempDir.path}/report.pdf');
    final random = Random(7);
    fileBytes = List<int>.generate(300 * 1024 + 17, (_) => random.nextInt(256));
    await file.writeAsBytes(fileBytes, flush: true);

    api = FakeTransport()
      ..onPost(
        '/uploads/sign',
        json: {
          'data': {
            'url': signedUrl,
            'headers': {'Content-Type': 'application/pdf'},
          },
        },
      );
    sessionInvalidations = 0;
    manager = NetKitManager(
      baseUrl: 'https://api.example.com',
      refreshTokenPath: '/auth/refresh',
      dataKey: 'data',
      transport: api,
      onSessionInvalidated: (_) => sessionInvalidations++,
    )
      ..setAccessToken('test-token')
      ..setRefreshToken('refresh-token');

    storageAdapter = RecordingHttpClientAdapter()
      ..drainStream = true
      ..collectBody = true;
    storage = DioNetKitTransport(httpClientAdapter: storageAdapter);
  });

  tearDown(() async {
    storage.close();
    manager.dispose();
    await tempDir.delete(recursive: true);
  });

  Future<_SignedUploadModel> requestSignedUrl() {
    return manager.requestModel<_SignedUploadModel>(
      path: '/uploads/sign',
      method: RequestMethod.post,
      model: const _SignedUploadModel(),
      body: {'fileName': 'report.pdf', 'size': fileBytes.length},
    );
  }

  RawHttpRequest uploadRequest(
    _SignedUploadModel signed, {
    NetKitCancellationToken? token,
    void Function(int, int)? onSendProgress,
  }) {
    return RawHttpRequest(
      uri: Uri.parse(signed.url!),
      method: RawHttpMethod.put,
      headers: signed.headers,
      body: StreamRawHttpBody(
        stream: file.openRead(),
        contentLength: fileBytes.length,
      ),
      cancellationToken: token,
      onSendProgress: onSendProgress,
    );
  }

  group('signed storage upload flow', () {
    test('API call carries the JWT; storage PUT carries only signed headers',
        () async {
      final signed = await requestSignedUrl();

      expect(api.requests.single.headers['Authorization'], 'Bearer test-token');
      expect(api.requests.single.uri.path, '/uploads/sign');
      expect(signed.url, signedUrl);

      final progress = <(int, int)>[];
      final response = await storage.send(
        uploadRequest(
          signed,
          onSendProgress: (sent, total) => progress.add((sent, total)),
        ),
      );

      expect(response.statusCode, 200);
      final put = storageAdapter.lastOptions!;
      expect(put.method, 'PUT');
      expect(put.uri.toString(), signedUrl);
      expect(put.headers.keys.map((k) => k.toLowerCase()).toSet(), {
        'content-type',
        'content-length',
      });
      expect(put.headers['content-type'], 'application/pdf');
      expect(put.headers['content-length'].toString(), '${fileBytes.length}');
      expect(put.headers['Authorization'], isNull);
      expect(put.headers['authorization'], isNull);

      // Streamed, not materialized: the adapter saw the File stream itself.
      expect(storageAdapter.lastData, isA<Stream<List<int>>>());
      expect(storageAdapter.lastData, isNot(isA<List<int>>()));
      expect(storageAdapter.consumedChunks, greaterThan(1));
      expect(storageAdapter.bodyBytes, fileBytes);

      expect(progress, isNotEmpty);
      expect(progress.last, (fileBytes.length, fileBytes.length));
    });

    test('storage 401 is returned as a response and never refreshes the JWT',
        () async {
      final signed = await requestSignedUrl();
      storageAdapter.statusCode = 401;
      final apiCallsBefore = api.requests.length;

      final response = await storage.send(uploadRequest(signed));

      expect(response.statusCode, 401);
      expect(response, isA<RawHttpResponse>());
      expect(api.requests, hasLength(apiCallsBefore));
      expect(
        api.requests.where((r) => r.uri.path.contains('refresh')),
        isEmpty,
      );
      expect(sessionInvalidations, 0);
      expect(manager.getAllHeaders()['Authorization'], 'Bearer test-token');
      expect(storageAdapter.requests, hasLength(1));
    });

    test('an unauthenticated API call is possible with AuthPolicy.none',
        () async {
      await manager.requestModel<_SignedUploadModel>(
        path: '/uploads/sign',
        method: RequestMethod.post,
        model: const _SignedUploadModel(),
        body: const {'fileName': 'report.pdf'},
        authPolicy: AuthPolicy.none,
      );

      expect(api.requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('cancelling mid-upload stops the file stream', () async {
      final signed = await requestSignedUrl();
      final token = NetKitCancellationToken();
      storageAdapter.onChunk = (_) async {
        if (storageAdapter.consumedChunks == 2) {
          token.cancel();
        }
      };

      await expectLater(
        storage.send(uploadRequest(signed, token: token)),
        throwsA(
          isA<RawHttpException>().having(
            (error) => error.type,
            'type',
            RawHttpFailureType.cancellation,
          ),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(storageAdapter.consumedBytes, lessThan(fileBytes.length));
      expect(token.isCancelled, isTrue);
    });
  });
}
