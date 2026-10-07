import 'dart:async';

import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

/// Replaces the outgoing body with a single-shot stream.
class _SingleShotBody extends NetKitInterceptor {
  const _SingleShotBody();

  @override
  RawHttpRequest onRequest(RawHttpRequest request) => request.copyWith(
        body: StreamRawHttpBody(
          stream: Stream.value(const [1, 2, 3]),
          contentLength: 3,
        ),
      );
}

/// Redirects are followed by the manager, never by the transport, so the
/// origin policy applies to every hop.
void main() {
  late FakeTransport transport;

  NetKitManager build({
    bool allowCrossOriginRequests = false,
    List<NetKitInterceptor> interceptors = const [],
  }) {
    final manager = NetKitManager(
      baseUrl: 'https://api.example.com/v1',
      transport: transport,
      headers: {'X-Api-Key': 'api-key', 'Accept-Language': 'en'},
      allowCrossOriginRequests: allowCrossOriginRequests,
      interceptors: interceptors,
    )..setAccessToken('test-token');
    addTearDown(manager.dispose);
    return manager;
  }

  void redirect(String path, int status, String location) {
    transport.onAny(
      path,
      status: status,
      headers: {
        'Location': [location],
      },
    );
  }

  TypeMatcher<ApiException> invalidRequest(String message) =>
      isA<ApiException>()
          .having((e) => e.type, 'type', ApiFailureType.invalidRequest)
          .having((e) => e.message, 'message', message);

  setUp(() {
    transport = FakeTransport()
      ..fallback = ((_) => FakeTransport.jsonResponse(200, {'ok': true}))
      ..onAny('/v1/final', json: {'landed': true});
  });

  test('same-origin 302 with a relative Location is followed with headers',
      () async {
    redirect('/v1/old', 302, '/v1/final');

    await build().requestVoid(path: '/old', method: RequestMethod.get);

    expect(transport.requests, hasLength(2));
    final hop = transport.lastRequest!;
    expect(hop.uri.toString(), 'https://api.example.com/v1/final');
    expect(hop.method, RawHttpMethod.get);
    expect(hop.headers['Authorization'], 'Bearer test-token');
    expect(hop.headers['X-Api-Key'], 'api-key');
  });

  test('302 after POST becomes a body-less GET', () async {
    redirect('/v1/old', 302, '/v1/final');

    await build().requestVoid(
      path: '/old',
      method: RequestMethod.post,
      body: {'a': 1},
    );

    final hop = transport.lastRequest!;
    expect(transport.requests.first.method, RawHttpMethod.post);
    expect(hop.method, RawHttpMethod.get);
    expect(hop.body, isNull);
    expect(hop.headers['Content-Type'], isNull);
  });

  test('301 after POST becomes a body-less GET', () async {
    redirect('/v1/old', 301, '/v1/final');

    await build().requestVoid(
      path: '/old',
      method: RequestMethod.post,
      body: {'a': 1},
    );

    expect(transport.lastRequest!.method, RawHttpMethod.get);
    expect(transport.lastRequest!.body, isNull);
  });

  test('303 becomes a GET', () async {
    redirect('/v1/old', 303, '/v1/final');

    await build().requestVoid(
      path: '/old',
      method: RequestMethod.put,
      body: {'a': 1},
    );

    expect(transport.lastRequest!.method, RawHttpMethod.get);
    expect(transport.lastRequest!.body, isNull);
  });

  test('307 keeps PUT and replays the bytes body', () async {
    redirect('/v1/old', 307, '/v1/final');

    await build().uploadRawData<VoidModel>(
      path: '/old',
      model: VoidModel(),
      data: const [9, 8, 7],
      method: RequestMethod.put,
    );

    expect(transport.requests, hasLength(2));
    expect(transport.lastRequest!.method, RawHttpMethod.put);
    expect(transport.lastRequest!.body, isA<BytesRawHttpBody>());
    expect(transport.bodies[1], transport.bodies[0]);
    expect(transport.bodies[1], [9, 8, 7]);
    expect(
      transport.lastRequest!.headers['Content-Type'],
      'application/octet-stream',
    );
  });

  test('307 with a single-shot body is refused', () async {
    // The manager only builds replayable bodies; an interceptor is the only
    // way a StreamRawHttpBody reaches the redirect logic.
    redirect('/v1/old', 307, '/v1/final');

    await expectLater(
      build(interceptors: const [_SingleShotBody()]).requestVoid(
        path: '/old',
        method: RequestMethod.put,
        body: {'a': 1},
      ),
      throwsA(
        invalidRequest(const NetKitErrorParams().nonReplayableBodyError)
            .having((e) => e.statusCode, 'statusCode', 307),
      ),
    );
    expect(transport.requests, hasLength(1));
  });

  test('redirect to another origin is blocked by default', () async {
    redirect('/v1/old', 302, 'https://other.example.org/final');

    await expectLater(
      build().requestVoid(path: '/old', method: RequestMethod.get),
      throwsA(
        invalidRequest(
          const NetKitErrorParams().crossOriginRequestBlockedError,
        ),
      ),
    );
    expect(transport.requests, hasLength(1));
  });

  test('cross-origin redirect strips credentials when allowed', () async {
    redirect('/v1/old', 302, 'https://other.example.org/final');

    await build(allowCrossOriginRequests: true).requestVoid(
      path: '/old',
      method: RequestMethod.get,
      headers: {
        'X-Trace': 'abc',
        'Cookie': 'session=1',
      },
    );

    expect(transport.requests, hasLength(2));
    final first = transport.requests.first;
    expect(first.headers['Authorization'], 'Bearer test-token');
    expect(first.headers['Cookie'], 'session=1');

    final hop = transport.lastRequest!;
    expect(hop.uri.toString(), 'https://other.example.org/final');
    expect(
      hop.headers.keys.map((k) => k.toLowerCase()),
      isNot(
        anyOf(
          contains('authorization'),
          contains('cookie'),
          contains('x-api-key'),
          contains('accept-language'),
        ),
      ),
    );
    expect(hop.headers['X-Trace'], 'abc');
  });

  test('more than 5 redirects fails', () async {
    redirect('/v1/loop', 302, '/v1/loop');

    await expectLater(
      build().requestVoid(path: '/loop', method: RequestMethod.get),
      throwsA(invalidRequest(const NetKitErrorParams().tooManyRedirectsError)),
    );
    expect(transport.requests, hasLength(6));
  });

  test('3xx without Location is returned as a failed status', () async {
    transport.onAny('/v1/old', status: 302, json: {'message': 'moved'});

    await expectLater(
      build().requestVoid(path: '/old', method: RequestMethod.get),
      throwsA(
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiFailureType.response)
            .having((e) => e.statusCode, 'statusCode', 302)
            .having((e) => e.message, 'message', 'moved'),
      ),
    );
    expect(transport.requests, hasLength(1));
  });

  test('the transport always receives followRedirects == false', () async {
    redirect('/v1/old', 302, '/v1/final');

    await build().requestVoid(path: '/old', method: RequestMethod.get);
    await build().uploadRawData<VoidModel>(
      path: '/final',
      model: VoidModel(),
      data: const [1],
      method: RequestMethod.put,
    );

    expect(transport.requests, hasLength(3));
    expect(
      transport.requests.map((r) => r.followRedirects),
      everyElement(isFalse),
    );
  });
}
