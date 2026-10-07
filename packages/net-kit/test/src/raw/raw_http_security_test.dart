import 'dart:convert';

import 'package:net_kit/net_kit.dart';
import 'package:net_kit/net_kit_dio.dart';
import 'package:test/test.dart';

import '../../mocks/fake_transport.dart';
import '../../mocks/recording_http_client_adapter.dart';

final _signedUrl = Uri.parse(
  'https://storage.example.com/example-bucket/uploads/42/report.pdf'
  '?X-Algorithm=HMAC-SHA256'
  '&X-Credential=uploader%40example-project'
  '%2F20261007%2Fauto%2Fstorage%2Fsigned_request'
  '&X-Date=20261007T101500Z'
  '&X-Expires=600'
  '&X-SignedHeaders=content-type%3Bhost%3Bx-content-length-range'
  '&X-Signature=9f8e7d6c5b4a',
);

void main() {
  late RecordingHttpClientAdapter rawAdapter;
  late DioNetKitTransport raw;
  late NetKitManager manager;
  late FakeTransport api;
  var sessionInvalidations = 0;

  setUp(() {
    rawAdapter = RecordingHttpClientAdapter();
    raw = DioNetKitTransport(httpClientAdapter: rawAdapter);
    api = FakeTransport()..onAny('/me', json: {});
    sessionInvalidations = 0;
    manager = NetKitManager(
      baseUrl: 'https://api.example.com',
      refreshTokenPath: '/auth/refresh',
      transport: api,
      onSessionInvalidated: (_) => sessionInvalidations++,
    )
      ..setAccessToken('test-token')
      ..setRefreshToken('refresh-token')
      ..addHeader(const MapEntry('X-App-Version', '9.9.9'))
      ..addHeader(const MapEntry('Accept-Language', 'en'));
  });

  tearDown(() {
    raw.close();
    manager.dispose();
  });

  RawHttpRequest signedPut({
    Map<String, String> headers = const {},
    RawHttpBody? body,
    NetKitCancellationToken? token,
    void Function(int, int)? onSendProgress,
  }) {
    return RawHttpRequest(
      uri: _signedUrl,
      method: RawHttpMethod.put,
      headers: headers,
      body: body,
      cancellationToken: token,
      onSendProgress: onSendProgress,
    );
  }

  group('RawHttpClient isolation from NetKitManager', () {
    test('does not send the manager access token or base headers', () async {
      await raw.send(
        signedPut(
          headers: const {
            'Content-Type': 'application/pdf',
            'x-content-length-range': '0,10485760',
          },
          body: const BytesRawHttpBody([1, 2, 3]),
        ),
      );

      final sent = rawAdapter.lastOptions!.headers;
      final keys = sent.keys.map((k) => k.toLowerCase()).toSet();
      expect(keys, {
        'content-type',
        'x-content-length-range',
        'content-length',
      });
      expect(sent['authorization'], isNull);
      expect(sent['Authorization'], isNull);
      expect(sent['x-app-version'], isNull);
      expect(sent['accept-language'], isNull);
      expect(sent['content-type'], 'application/pdf');
      expect(sent['x-content-length-range'], '0,10485760');
      expect(sent['content-length'].toString(), '3');
      expect(
        jsonEncode(sent.values.map((v) => v.toString()).toList()),
        isNot(contains('test-token')),
      );
    });

    test('a 401 from storage returns a response and triggers no refresh',
        () async {
      rawAdapter
        ..statusCode = 401
        ..responseHeaders = {
          'www-authenticate': ['Bearer realm="storage"'],
        };

      final response = await raw.send(signedPut());

      expect(response.statusCode, 401);
      expect(response.header('WWW-Authenticate'), 'Bearer realm="storage"');
      expect(rawAdapter.requests, hasLength(1));
      expect(api.requests, isEmpty);
      expect(sessionInvalidations, 0);
      expect(manager.getAllHeaders()['Authorization'], 'Bearer test-token');
    });

    test('a 401 from storage does not touch a manager mid-flight', () async {
      rawAdapter.statusCode = 401;

      await Future.wait([
        manager.requestVoid(path: '/me', method: RequestMethod.get),
        raw.send(signedPut()),
      ]);

      expect(api.requests, hasLength(1));
      expect(api.requests.single.uri.path, '/me');
      expect(
        api.requests.single.headers['Authorization'],
        'Bearer test-token',
      );
      expect(rawAdapter.lastOptions!.headers['Authorization'], isNull);
      expect(sessionInvalidations, 0);
    });

    for (final status in const [401, 403, 404, 409, 429, 500, 503]) {
      test('does not retry a $status protocol response', () async {
        rawAdapter.statusCode = status;

        final response = await raw.send(signedPut());

        expect(response.statusCode, status);
        expect(rawAdapter.requests, hasLength(1));
      });
    }

    test('preserves the signed URL and percent-encoded query exactly',
        () async {
      await raw.send(signedPut());

      final sent = rawAdapter.lastOptions!.uri;
      expect(sent.toString(), _signedUrl.toString());
      expect(sent.query, _signedUrl.query);
      expect(sent.query, contains('%2F20261007%2Fauto%2Fstorage'));
      expect(sent.query, contains('%3Bhost%3B'));
      expect(sent.queryParameters['X-Algorithm'], 'HMAC-SHA256');
      expect(sent.queryParameters['X-Signature'], '9f8e7d6c5b4a');
      expect(
        rawAdapter.lastOptions!.baseUrl,
        isNot(contains('api.example.com')),
      );
    });

    test('streams a body with Content-Length, progress, and cancellation',
        () async {
      rawAdapter.drainStream = true;
      final progress = <(int, int)>[];
      final chunks = List.generate(8, (i) => List<int>.filled(1024, i));
      final stream = Stream<List<int>>.fromIterable(chunks);

      final response = await raw.send(
        signedPut(
          headers: const {'Content-Type': 'application/octet-stream'},
          body: StreamRawHttpBody(stream: stream, contentLength: 8 * 1024),
          onSendProgress: (sent, total) => progress.add((sent, total)),
        ),
      );

      expect(response.statusCode, 200);
      expect(rawAdapter.lastData, same(stream));
      expect(rawAdapter.consumedBytes, 8 * 1024);
      expect(
        rawAdapter.lastOptions!.headers['content-length'].toString(),
        '${8 * 1024}',
      );
      expect(progress.last, (8 * 1024, 8 * 1024));

      final token = NetKitCancellationToken();
      rawAdapter
        ..onChunk = (_) async {
          if (rawAdapter.consumedChunks == 2) {
            token.cancel();
          }
        }
        ..consumedChunks = 0;
      await expectLater(
        raw.send(
          signedPut(
            body: StreamRawHttpBody(
              stream: Stream<List<int>>.fromIterable(chunks),
              contentLength: 8 * 1024,
            ),
            token: token,
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
      expect(rawAdapter.consumedChunks, lessThan(8));
    });
  });
}
