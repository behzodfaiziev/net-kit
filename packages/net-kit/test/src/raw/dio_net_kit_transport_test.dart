import 'dart:async';

import 'package:net_kit/net_kit.dart';
import 'package:net_kit/net_kit_dio.dart';
import 'package:net_kit/src/core/net_kit_cancellation_token.dart';
import 'package:test/test.dart';

import '../../mocks/recording_http_client_adapter.dart';

void main() {
  late RecordingHttpClientAdapter adapter;
  late DioNetKitTransport client;

  RawHttpRequest request({
    Uri? uri,
    RawHttpMethod method = RawHttpMethod.put,
    Map<String, String> headers = const {},
    RawHttpBody? body,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    void Function(int sent, int total)? onSendProgress,
    void Function(int received, int total)? onReceiveProgress,
    bool followRedirects = false,
  }) {
    return RawHttpRequest(
      uri:
          uri ?? Uri.parse('https://storage.example.com/upload/session?id=abc'),
      method: method,
      headers: headers,
      body: body,
      timeout: timeout,
      cancellationToken: cancellationToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      followRedirects: followRedirects,
    );
  }

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

  group('DioNetKitTransport', () {
    test('is the RawHttpClient and the DioRawHttpClient alias', () {
      expect(client, isA<RawHttpClient>());
      expect(client, isA<NetKitTransport>());
      expect(client, isA<DioRawHttpClient>());
    });

    test('sends an absolute URL unchanged', () async {
      final uri = Uri.parse(
        'https://storage.example.com/upload/session?id=abc',
      );

      await client.send(request(uri: uri));

      expect(adapter.lastOptions!.uri.toString(), uri.toString());
      expect(adapter.lastOptions!.path, uri.toString());
    });

    test('preserves a percent-encoded signed URL byte for byte', () async {
      final uri = Uri.parse(
        'https://storage.example.com/bucket/dir%20one/file%2Bv1.bin'
        '?X-Algorithm=HMAC-SHA256'
        '&X-Credential=uploader%40example-project'
        '%2F20261007%2Fauto%2Fstorage%2Fsigned_request'
        '&X-Date=20261007T000000Z'
        '&X-Expires=900'
        '&X-SignedHeaders=content-type%3Bhost'
        '&X-Signature=0a1b2c3d',
      );

      await client.send(request(uri: uri));

      final sent = adapter.lastOptions!.uri;
      expect(sent.toString(), uri.toString());
      expect(sent.query, uri.query);
      expect(sent.path, uri.path);
      expect(sent.queryParameters['X-Signature'], '0a1b2c3d');
      expect(adapter.lastOptions!.queryParameters, isEmpty);
    });

    test('does not add Authorization unless the caller supplies it', () async {
      await client.send(request());

      expect(adapter.lastOptions!.headers['Authorization'], isNull);
      expect(adapter.lastOptions!.headers['authorization'], isNull);
    });

    test('does not imply Content-Type on a streaming PUT', () async {
      final stream = Stream<List<int>>.fromIterable([
        [1, 2, 3],
      ]);

      await client.send(
        request(
          body: StreamRawHttpBody(stream: stream, contentLength: 3),
        ),
      );

      expect(adapter.lastOptions!.headers['content-type'], isNull);
      expect(adapter.lastOptions!.contentType, isNull);
    });

    test('forwards a Stream body without flattening it', () async {
      final stream = Stream<List<int>>.fromIterable([
        [1],
        [2, 3],
      ]);

      await client.send(
        request(
          body: StreamRawHttpBody(stream: stream, contentLength: 3),
        ),
      );

      expect(adapter.lastData, isA<Stream<List<int>>>());
      expect(adapter.lastData, same(stream));
      expect(adapter.lastRequestStream, isNotNull);
    });

    test('forwards Content-Length from StreamRawHttpBody', () async {
      await client.send(
        request(
          body: const StreamRawHttpBody(
            stream: Stream.empty(),
            contentLength: 8388608,
          ),
        ),
      );

      expect(
        adapter.lastOptions!.headers['content-length']?.toString(),
        '8388608',
      );
    });

    test('preserves caller headers and does not mutate them', () async {
      final headers = {
        'Content-Type': 'application/octet-stream',
        'Content-Range': 'bytes 0-1023/2048',
      };

      await client.send(
        request(
          headers: headers,
          body: const StreamRawHttpBody(
            stream: Stream.empty(),
            contentLength: 1024,
          ),
        ),
      );

      expect(
        adapter.lastOptions!.headers['content-type'],
        'application/octet-stream',
      );
      expect(
        adapter.lastOptions!.headers['content-range'],
        'bytes 0-1023/2048',
      );
      expect(headers.containsKey('Content-Length'), isFalse);
      expect(headers.length, 2);
    });

    test('forwards per-request timeouts to Dio', () async {
      await client.send(
        request(
          timeout: const NetKitTimeout(
            connect: Duration(seconds: 1),
            send: Duration(seconds: 2),
            receive: Duration(seconds: 3),
          ),
        ),
      );

      final sent = adapter.lastOptions!;
      expect(sent.connectTimeout, const Duration(seconds: 1));
      expect(sent.sendTimeout, const Duration(seconds: 2));
      expect(sent.receiveTimeout, const Duration(seconds: 3));
    });

    test('leaves timeouts unset when the request has none', () async {
      await client.send(request());

      final sent = adapter.lastOptions!;
      expect(sent.connectTimeout, isNull);
      expect(sent.sendTimeout, isNull);
      expect(sent.receiveTimeout, isNull);
    });

    test('does not follow redirects unless asked', () async {
      await client.send(request());
      expect(adapter.lastOptions!.followRedirects, isFalse);

      await client.send(request(followRedirects: true));
      expect(adapter.lastOptions!.followRedirects, isTrue);
    });

    test('returns 308 with Range as RawHttpResponse', () async {
      adapter
        ..statusCode = 308
        ..responseHeaders = {
          'range': ['bytes=0-8388607'],
        };

      final response = await client.send(request());

      expect(response, isA<RawHttpResponse>());
      expect(response.statusCode, 308);
      expect(response.header('Range'), 'bytes=0-8388607');
      expect(response, isNot(isA<ApiException>()));
    });

    test('returns the body as bytes and reports receive progress', () async {
      final progress = <(int, int)>[];
      adapter
        ..responseBytes = [1, 2, 3, 4, 5]
        ..responseHeaders = {
          'content-length': ['5'],
        };

      final response = await client.send(
        request(
          method: RawHttpMethod.get,
          onReceiveProgress: (received, total) {
            progress.add((received, total));
          },
        ),
      );

      expect(response.bodyBytes, [1, 2, 3, 4, 5]);
      expect(response.contentLength, 5);
      expect(progress.last, (5, 5));
    });

    test('header returns the first of repeated values', () async {
      adapter.responseHeaders = {
        'accept-ranges': ['bytes', 'none'],
      };

      final response = await client.send(request());

      expect(response.header('Accept-Ranges'), 'bytes');
      expect(response.headerValues('Accept-Ranges'), ['bytes', 'none']);
    });

    test('response headers are unmodifiable copies', () async {
      adapter.responseHeaders = {
        'set-cookie': ['a=1', 'b=2'],
      };

      final response = await client.send(request());

      expect(response.headerValues('Set-Cookie'), ['a=1', 'b=2']);
      expect(
        () => response.headers['x'] = ['y'],
        throwsUnsupportedError,
      );
      expect(
        () => response.headers['set-cookie']!.add('c=3'),
        throwsUnsupportedError,
      );
    });

    for (final status in const [401, 403, 404, 409, 410, 429, 500, 503]) {
      test('returns $status as RawHttpResponse without retrying', () async {
        adapter.statusCode = status;

        final response = await client.send(request());

        expect(response.statusCode, status);
        expect(response, isA<RawHttpResponse>());
        expect(adapter.requests, hasLength(1));
      });
    }

    for (final (dioType, rawType) in const [
      (DioExceptionType.connectionTimeout, RawHttpFailureType.timeout),
      (DioExceptionType.sendTimeout, RawHttpFailureType.timeout),
      (DioExceptionType.receiveTimeout, RawHttpFailureType.timeout),
      (DioExceptionType.connectionError, RawHttpFailureType.connection),
      (DioExceptionType.badCertificate, RawHttpFailureType.tls),
      (DioExceptionType.cancel, RawHttpFailureType.cancellation),
      (DioExceptionType.badResponse, RawHttpFailureType.invalidResponse),
      (DioExceptionType.unknown, RawHttpFailureType.unknown),
    ]) {
      test('maps ${dioType.name} to $rawType', () async {
        adapter.throwType = dioType;

        await expectLater(
          client.send(request()),
          throwsA(
            isA<RawHttpException>()
                .having((error) => error.type, 'type', rawType)
                .having((error) => error.cause, 'cause', isA<DioException>()),
          ),
        );
      });
    }

    test('maps transformTimeout (Dio 5.10+) to timeout', () async {
      final transformTimeout =
          DioExceptionType.values.cast<DioExceptionType?>().firstWhere(
                (type) => type!.name == 'transformTimeout',
                orElse: () => null,
              );
      if (transformTimeout == null) {
        markTestSkipped('DioExceptionType.transformTimeout requires Dio 5.10+');
        return;
      }
      adapter.throwType = transformTimeout;

      await expectLater(
        client.send(request()),
        throwsA(
          isA<RawHttpException>().having(
            (error) => error.type,
            'type',
            RawHttpFailureType.timeout,
          ),
        ),
      );
    });

    test('every DioExceptionType of the resolved Dio maps without throwing',
        () async {
      for (final type in DioExceptionType.values) {
        adapter.throwType = type;
        await expectLater(
          client.send(request()),
          throwsA(isA<RawHttpException>()),
          reason: 'DioExceptionType.${type.name} must map to a raw failure',
        );
      }
    });

    test('a response without a status code is invalidResponse', () async {
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) =>
              handler.resolve(Response<Object>(requestOptions: options)),
        ),
      );
      final token = NetKitCancellationToken();

      await expectLater(
        client.send(request(cancellationToken: token)),
        throwsA(
          isA<RawHttpException>().having(
            (error) => error.type,
            'type',
            RawHttpFailureType.invalidResponse,
          ),
        ),
      );
      expect(netKitCancellationBindingCount(token), 0);
    });

    test('does not inherit NetKitManager access tokens', () async {
      final manager = NetKitManager(
        baseUrl: 'https://api.example.com',
      )..setAccessToken('test-token');

      try {
        await client.send(request());

        expect(adapter.lastOptions!.headers['Authorization'], isNull);
        expect(
          manager.getAllHeaders()['Authorization'],
          contains('test-token'),
        );
      } finally {
        manager.dispose();
      }
    });

    test('uses the injected HttpClientAdapter', () async {
      adapter.statusCode = 201;

      final response = await client.send(request());

      expect(adapter.lastOptions, isNotNull);
      expect(response.statusCode, 201);
    });

    test('owned Dio has implied-content-type disabled', () async {
      await client.send(
        request(
          method: RawHttpMethod.post,
          body: const StringRawHttpBody('{"a":1}'),
        ),
      );

      expect(adapter.lastOptions!.contentType, isNull);
      expect(adapter.lastOptions!.headers['content-type'], isNull);
    });

    test('forwards onSendProgress without buffering the stream', () async {
      final progress = <(int, int)>[];
      adapter.drainStream = true;

      await client.send(
        request(
          body: StreamRawHttpBody(
            stream: Stream<List<int>>.fromIterable([
              [1, 2, 3, 4],
            ]),
            contentLength: 4,
          ),
          onSendProgress: (sent, total) {
            progress.add((sent, total));
          },
        ),
      );

      expect(adapter.lastData, isA<Stream<List<int>>>());
      expect(progress, isNotEmpty);
      expect(progress.last.$2, 4);
    });

    test('cancel surfaces as RawHttpException cancellation', () async {
      adapter
        ..started = Completer<void>()
        ..waitForCancel = true;
      final token = NetKitCancellationToken();

      final future = client.send(request(cancellationToken: token));
      await adapter.started!.future;
      token.cancel();

      await expectLater(future, throwsA(isCancellation));
      expect(netKitCancellationBindingCount(token), 0);
    });

    test('cancelling before send fails fast without reaching the adapter',
        () async {
      final token = NetKitCancellationToken()..cancel();

      await expectLater(
        client.send(request(cancellationToken: token)),
        throwsA(isCancellation),
      );
      expect(adapter.requests, isEmpty);
      expect(netKitCancellationBindingCount(token), 0);
    });

    test('releases the cancellation binding after a completed request',
        () async {
      final token = NetKitCancellationToken();

      await client.send(request(cancellationToken: token));

      expect(netKitCancellationBindingCount(token), 0);
      expect(token.cancel, returnsNormally);
    });

    test('releases the cancellation binding after a transport failure',
        () async {
      adapter.throwType = DioExceptionType.connectionError;
      final token = NetKitCancellationToken();

      await expectLater(
        client.send(request(cancellationToken: token)),
        throwsA(isA<RawHttpException>()),
      );

      expect(netKitCancellationBindingCount(token), 0);
    });

    test('a token reused sequentially still cancels the later request',
        () async {
      final token = NetKitCancellationToken();
      await client.send(request(cancellationToken: token));

      adapter
        ..started = Completer<void>()
        ..waitForCancel = true;
      final future = client.send(request(cancellationToken: token));
      await adapter.started!.future;
      token.cancel();

      await expectLater(future, throwsA(isCancellation));
    });

    test('one token cancels every concurrently in-flight request', () async {
      final secondAdapter = RecordingHttpClientAdapter()
        ..started = Completer<void>()
        ..waitForCancel = true;
      final secondClient = DioNetKitTransport(
        httpClientAdapter: secondAdapter,
      );
      adapter
        ..started = Completer<void>()
        ..waitForCancel = true;
      final token = NetKitCancellationToken();

      final first = client.send(request(cancellationToken: token));
      final second = secondClient.send(
        request(
          uri: Uri.parse('https://other.example.org/other'),
          cancellationToken: token,
        ),
      );
      await adapter.started!.future;
      await secondAdapter.started!.future;
      expect(netKitCancellationBindingCount(token), 2);

      token.cancel();

      await expectLater(first, throwsA(isCancellation));
      await expectLater(second, throwsA(isCancellation));
      expect(netKitCancellationBindingCount(token), 0);
      secondClient.close();
    });

    test('forwards BytesRawHttpBody without JSON content type', () async {
      await client.send(
        request(body: const BytesRawHttpBody([9, 8, 7])),
      );

      expect(adapter.lastData, equals([9, 8, 7]));
      expect(adapter.lastOptions!.contentType, isNull);
      expect(
        adapter.lastOptions!.headers['content-length']?.toString(),
        '3',
      );
    });

    test('forwards StringRawHttpBody without JSON content type', () async {
      await client.send(
        request(body: const StringRawHttpBody('plain')),
      );

      expect(adapter.lastData, 'plain');
      expect(adapter.lastOptions!.contentType, isNull);
    });

    test('HEAD with a null body sends no request stream', () async {
      await client.send(request(method: RawHttpMethod.head));

      expect(adapter.lastData, isNull);
      expect(adapter.lastRequestStream, isNull);
    });

    test('GET with a null body sends no request stream', () async {
      await client.send(request(method: RawHttpMethod.get));

      expect(adapter.lastData, isNull);
      expect(adapter.lastRequestStream, isNull);
    });

    test('OPTIONS is sent with the OPTIONS verb', () async {
      await client.send(request(method: RawHttpMethod.options));

      expect(adapter.lastOptions!.method, 'OPTIONS');
      expect(adapter.lastData, isNull);
    });

    test('close closes the owned adapter', () {
      client.close();

      expect(adapter.closeCalls, 1);
    });
  });
}
