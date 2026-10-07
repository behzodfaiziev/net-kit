import 'dart:async';
import 'dart:convert';

import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

class _ItemModel extends INetKitModel {
  const _ItemModel({this.id});

  final int? id;

  @override
  _ItemModel fromJson(Map<String, dynamic> json) =>
      _ItemModel(id: json['id'] as int?);

  @override
  Map<String, dynamic>? toJson() => {'id': id};
}

/// The smallest possible transport: canned status, headers, and body.
class _CannedTransport implements NetKitTransport {
  _CannedTransport({
    this.statusCode = 200,
    this.contentType = 'application/json',
    this.body = '{}',
    this.error,
  });

  final int statusCode;
  final String contentType;
  final String body;
  final RawHttpException? error;
  final List<RawHttpRequest> sent = [];
  int closeCalls = 0;

  @override
  Future<RawHttpResponse> send(RawHttpRequest request) async {
    sent.add(request);
    if (error != null) {
      throw error!;
    }
    return RawHttpResponse(
      statusCode: statusCode,
      headers: {
        'content-type': [contentType],
      },
      bodyBytes: utf8.encode(body),
    );
  }

  @override
  Future<RawHttpStreamedResponse> sendStreamed(RawHttpRequest request) async {
    final response = await send(request);
    return RawHttpStreamedResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: Stream.value(response.bodyBytes),
    );
  }

  @override
  void close({bool force = false}) => closeCalls++;
}

/// `NetKitManager` depends on the `NetKitTransport` contract only.
void main() {
  NetKitManager build(NetKitTransport transport) {
    final manager = NetKitManager(
      baseUrl: 'https://api.example.com',
      transport: transport,
    );
    addTearDown(manager.dispose);
    return manager;
  }

  Matcher failure(ApiFailureType type, int? statusCode, String message) =>
      isA<ApiException>()
          .having((e) => e.type, 'type', type)
          .having((e) => e.statusCode, 'statusCode', statusCode)
          .having((e) => e.message, 'message', message);

  group('custom transport', () {
    test('requestModel decodes a canned JSON object', () async {
      final transport = _CannedTransport(body: '{"id": 7}');

      final item = await build(transport).requestModel<_ItemModel>(
        path: '/items/7',
        method: RequestMethod.get,
        model: const _ItemModel(),
      );

      expect(item.id, 7);
      expect(
        transport.sent.single.uri.toString(),
        'https://api.example.com/items/7',
      );
    });

    test('requestList decodes a canned JSON array', () async {
      final transport = _CannedTransport(body: '[{"id": 1}, {"id": 2}]');

      final items = await build(transport).requestList<_ItemModel>(
        path: '/items',
        method: RequestMethod.get,
        model: const _ItemModel(),
      );

      expect(items.map((i) => i.id), [1, 2]);
    });

    test('requestVoid accepts an empty 204', () async {
      final transport = _CannedTransport(statusCode: 204, body: '');

      await expectLater(
        build(transport).requestVoid(
          path: '/items/1',
          method: RequestMethod.delete,
        ),
        completes,
      );
    });

    test('uploadRawData sends the bytes through the transport', () async {
      final transport = _CannedTransport(body: '{"id": 3}');

      final item = await build(transport).uploadRawData<_ItemModel>(
        path: '/blobs',
        model: const _ItemModel(),
        data: const [1, 2, 3],
        method: RequestMethod.post,
        contentType: 'image/png',
      );

      expect(item.id, 3);
      final sent = transport.sent.single;
      expect(sent.method, RawHttpMethod.post);
      expect((sent.body! as BytesRawHttpBody).bytes, [1, 2, 3]);
      expect(sent.headers['Content-Type'], 'image/png');
    });
  });

  group('transport ownership', () {
    test('dispose does not close an injected transport', () {
      final transport = _CannedTransport();
      NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: transport,
      ).dispose();

      expect(transport.closeCalls, 0);
    });

    test('a manager built without a transport creates its own', () {
      final manager = NetKitManager(baseUrl: 'https://api.example.com');
      addTearDown(manager.dispose);

      expect(manager.transport, isNot(isA<FakeTransport>()));
      expect(manager.transport, isNot(isA<_CannedTransport>()));
    });
  });

  group('transport failure mapping', () {
    const params = NetKitErrorParams();

    RawHttpException raw(RawHttpFailureType type) =>
        RawHttpException(message: 'boom', type: type);

    test('timeout -> (timeout, 408, timeoutError)', () async {
      await expectLater(
        build(_CannedTransport(error: raw(RawHttpFailureType.timeout)))
            .requestVoid(path: '/x', method: RequestMethod.get),
        throwsA(failure(ApiFailureType.timeout, 408, params.timeoutError)),
      );
    });

    test('connection -> (transport, 503, socketExceptionError)', () async {
      await expectLater(
        build(_CannedTransport(error: raw(RawHttpFailureType.connection)))
            .requestVoid(path: '/x', method: RequestMethod.get),
        throwsA(
          failure(ApiFailureType.transport, 503, params.socketExceptionError),
        ),
      );
    });

    test('cancellation -> (cancelled, null)', () async {
      await expectLater(
        build(_CannedTransport(error: raw(RawHttpFailureType.cancellation)))
            .requestVoid(path: '/x', method: RequestMethod.get),
        throwsA(
          failure(
            ApiFailureType.cancelled,
            null,
            params.requestCancelledError,
          ),
        ),
      );
    });

    test('offline -> (transport, 503, noInternetError) without sending',
        () async {
      final transport = _CannedTransport();
      final status = StreamController<bool>();
      addTearDown(status.close);
      final manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: transport,
        internetStatusStream: status.stream,
      );
      addTearDown(manager.dispose);
      status.add(false);
      await pumpEventQueue();

      await expectLater(
        manager.requestVoid(path: '/x', method: RequestMethod.get),
        throwsA(
          failure(ApiFailureType.transport, 503, params.noInternetError),
        ),
      );
      expect(transport.sent, isEmpty);
    });
  });

  group('response decoding', () {
    test('application/problem+json is decoded as JSON', () async {
      final transport = _CannedTransport(
        contentType: 'application/problem+json',
        body: '{"id": 11}',
      );

      final item = await build(transport).requestModel<_ItemModel>(
        path: '/items/11',
        method: RequestMethod.get,
        model: const _ItemModel(),
      );

      expect(item.id, 11);
    });

    test('a non-JSON content type body is a decoding error', () async {
      final transport = _CannedTransport(
        contentType: 'text/html',
        body: '<html><body>Hi</body></html>',
      );

      await expectLater(
        build(transport).requestModel<_ItemModel>(
          path: '/items/1',
          method: RequestMethod.get,
          model: const _ItemModel(),
        ),
        throwsA(
          failure(
            ApiFailureType.decoding,
            417,
            const NetKitErrorParams().notMapTypeError,
          ),
        ),
      );
    });
  });
}
