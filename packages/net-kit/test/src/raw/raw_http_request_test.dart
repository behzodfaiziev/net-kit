import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

void main() {
  group('RawHttpRequest', () {
    test('accepts an absolute https URI', () {
      final request = RawHttpRequest(
        uri: Uri.parse('https://storage.example.com/upload/session?id=abc'),
        method: RawHttpMethod.put,
      );

      expect(request.uri.scheme, 'https');
      expect(request.uri.host, 'storage.example.com');
      expect(request.uri.queryParameters['id'], 'abc');
    });

    test('accepts an absolute http URI', () {
      final request = RawHttpRequest(
        uri: Uri.parse('http://localhost:8080/upload'),
        method: RawHttpMethod.post,
      );

      expect(request.uri.scheme, 'http');
      expect(request.uri.host, 'localhost');
    });

    test('throws ArgumentError for a relative URI', () {
      expect(
        () => RawHttpRequest(
          uri: Uri.parse('/upload'),
          method: RawHttpMethod.put,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'uri',
          ),
        ),
      );
    });

    test('throws ArgumentError for a hostless URI', () {
      expect(
        () => RawHttpRequest(
          uri: Uri.parse('file:///data/upload.bin'),
          method: RawHttpMethod.get,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('defaults to no body, no timeout, and no redirect following', () {
      final request = RawHttpRequest(
        uri: Uri.parse('https://api.example.com/items'),
        method: RawHttpMethod.get,
      );

      expect(request.headers, isEmpty);
      expect(request.body, isNull);
      expect(request.timeout, isNull);
      expect(request.cancellationToken, isNull);
      expect(request.onSendProgress, isNull);
      expect(request.onReceiveProgress, isNull);
      expect(request.followRedirects, isFalse);
    });

    test('stores caller-owned fields unchanged', () {
      final headers = {'Content-Type': 'application/octet-stream'};
      const stream = Stream<List<int>>.empty();
      final token = NetKitCancellationToken();
      const timeout = NetKitTimeout(
        connect: Duration(seconds: 1),
        send: Duration(seconds: 2),
        receive: Duration(seconds: 3),
      );
      void onSend(int sent, int total) {}
      void onReceive(int received, int total) {}

      const body = StreamRawHttpBody(stream: stream, contentLength: 4);
      final request = RawHttpRequest(
        uri: Uri.parse('https://storage.example.com/upload'),
        method: RawHttpMethod.put,
        headers: headers,
        body: body,
        timeout: timeout,
        cancellationToken: token,
        onSendProgress: onSend,
        onReceiveProgress: onReceive,
        followRedirects: true,
      );

      expect(request.headers, same(headers));
      expect(request.body, same(body));
      expect(request.timeout, same(timeout));
      expect(request.timeout!.connect, const Duration(seconds: 1));
      expect(request.timeout!.send, const Duration(seconds: 2));
      expect(request.timeout!.receive, const Duration(seconds: 3));
      expect(request.cancellationToken, same(token));
      expect(request.onSendProgress, same(onSend));
      expect(request.onReceiveProgress, same(onReceive));
      expect(request.followRedirects, isTrue);
    });

    group('copyWith', () {
      final token = NetKitCancellationToken();
      void onProgress(int a, int b) {}
      final original = RawHttpRequest(
        uri: Uri.parse('https://api.example.com/items'),
        method: RawHttpMethod.post,
        headers: const {'Authorization': 'Bearer test-token'},
        body: const StringRawHttpBody('{"a":1}'),
        timeout: const NetKitTimeout(send: Duration(seconds: 2)),
        cancellationToken: token,
        onSendProgress: onProgress,
        onReceiveProgress: onProgress,
      );

      test('with no arguments keeps every field', () {
        final copy = original.copyWith();

        expect(copy, isNot(same(original)));
        expect(copy.uri, original.uri);
        expect(copy.method, original.method);
        expect(copy.headers, same(original.headers));
        expect(copy.body, same(original.body));
        expect(copy.timeout, same(original.timeout));
        expect(copy.cancellationToken, same(token));
        expect(copy.onSendProgress, same(onProgress));
        expect(copy.onReceiveProgress, same(onProgress));
        expect(copy.followRedirects, isFalse);
      });

      test('replaces only the given fields', () {
        final redirected = Uri.parse('https://other.example.org/items');
        const newTimeout = NetKitTimeout(receive: Duration(seconds: 9));

        final copy = original.copyWith(
          uri: redirected,
          method: RawHttpMethod.get,
          headers: const {},
          timeout: newTimeout,
          followRedirects: true,
        );

        expect(copy.uri, redirected);
        expect(copy.method, RawHttpMethod.get);
        expect(copy.headers, isEmpty);
        expect(copy.body, same(original.body));
        expect(copy.timeout, same(newTimeout));
        expect(copy.cancellationToken, same(token));
        expect(copy.followRedirects, isTrue);
      });

      test('replaces the body', () {
        const body = BytesRawHttpBody([1]);

        final copy = original.copyWith(body: body);

        expect(copy.body, same(body));
      });

      test('clearBody drops the body even when one is passed', () {
        expect(original.copyWith(clearBody: true).body, isNull);
        expect(
          original
              .copyWith(body: const BytesRawHttpBody([1]), clearBody: true)
              .body,
          isNull,
        );
        expect(original.body, isNotNull);
      });

      test('rejects a relative URI like the constructor', () {
        expect(
          () => original.copyWith(uri: Uri.parse('/relative')),
          throwsArgumentError,
        );
      });
    });
  });
}
