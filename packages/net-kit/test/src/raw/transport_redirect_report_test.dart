import 'dart:async';
import 'dart:typed_data';

import 'package:net_kit/net_kit.dart';
import 'package:net_kit/net_kit_dio.dart';
import 'package:test/test.dart';

import '../../mocks/recording_http_client_adapter.dart';

/// `RawHttpResponse.redirected` reports redirects the HTTP client followed on
/// its own. Browsers follow redirects unconditionally and only report that
/// one happened; the `dart:io` client lists followed hops.
void main() {
  late RecordingHttpClientAdapter adapter;
  late DioNetKitTransport transport;

  RawHttpRequest request() => RawHttpRequest(
        uri: Uri.parse('https://api.example.com/auth/refresh'),
        method: RawHttpMethod.post,
      );

  setUp(() {
    adapter = RecordingHttpClientAdapter();
    transport = DioNetKitTransport(httpClientAdapter: adapter);
  });

  tearDown(() => transport.close());

  test('the transport always asks the client not to follow redirects',
      () async {
    await transport.send(request());

    expect(adapter.lastOptions!.followRedirects, isFalse);
  });

  test('a plain response is not redirected', () async {
    final response = await transport.send(request());

    expect(response.redirected, isFalse);
  });

  test('a browser-style followed redirect is reported', () async {
    adapter
      ..statusCode = 200
      ..responseIsRedirect = true;

    final response = await transport.send(request());

    expect(response.statusCode, 200);
    expect(response.redirected, isTrue);
  });

  test('an unfollowed 3xx is a redirect status, not a followed redirect',
      () async {
    adapter
      ..statusCode = 302
      ..responseIsRedirect = true
      ..responseHeaders = {
        'location': ['/elsewhere'],
      };

    final response = await transport.send(request());

    expect(response.statusCode, 302);
    expect(response.redirected, isFalse);
  });

  test('hops followed by the dart:io client are reported', () async {
    adapter.responseRedirects = [
      RedirectRecord(302, 'GET', Uri.parse('https://api.example.com/next')),
    ];

    final response = await transport.send(request());

    expect(response.redirected, isTrue);
  });

  test('streamed responses report followed redirects too', () async {
    adapter
      ..responseIsRedirect = true
      ..responseStream = Stream<Uint8List>.value(Uint8List.fromList([1]));

    final response = await transport.sendStreamed(request());
    await response.body.drain<void>();

    expect(response.redirected, isTrue);
  });
}
