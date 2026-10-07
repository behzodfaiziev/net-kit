import 'dart:convert';
import 'dart:io';

import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

class _UserModel extends INetKitModel {
  const _UserModel({this.id, this.name});

  final int? id;
  final String? name;

  @override
  _UserModel fromJson(Map<String, dynamic> json) =>
      _UserModel(id: json['id'] as int?, name: json['name'] as String?);

  @override
  Map<String, dynamic>? toJson() => {'id': id, 'name': name};
}

/// Pins the request semantics a transport sees from `NetKitManager`.
void main() {
  late FakeTransport transport;
  late NetKitManager manager;

  setUp(() {
    transport = FakeTransport()
      ..fallback = (_) => FakeTransport.jsonResponse(200, {
            'data': {'id': 1, 'name': 'Ada'},
          });
    manager = NetKitManager(
      baseUrl: 'https://api.example.com',
      transport: transport,
      dataKey: 'data',
    );
    addTearDown(manager.dispose);
  });

  group('request semantics', () {
    test('GET appends query parameters and decodes the model', () async {
      final user = await manager.requestModel<_UserModel>(
        path: '/users/1',
        method: RequestMethod.get,
        model: const _UserModel(),
        queryParameters: {'expand': 'profile', 'page': 2},
      );

      final sent = transport.lastRequest!;
      expect(sent.method, RawHttpMethod.get);
      expect(
        sent.uri.toString(),
        'https://api.example.com/users/1?expand=profile&page=2',
      );
      expect(user.id, 1);
      expect(user.name, 'Ada');
    });

    test('POST sends a JSON body with JSON content type', () async {
      await manager.requestModel<_UserModel>(
        path: '/users',
        method: RequestMethod.post,
        model: const _UserModel(),
        body: {'name': 'Ada'},
      );

      final sent = transport.lastRequest!;
      expect(sent.method, RawHttpMethod.post);
      expect(jsonDecode(utf8.decode(transport.lastBody!)), {'name': 'Ada'});
      expect(sent.headers['Content-Type'], startsWith('application/json'));
    });

    test('form-urlencoded body when the per-request Content-Type says so',
        () async {
      await manager.requestVoid(
        path: '/login',
        method: RequestMethod.post,
        body: {'user': 'ada', 'note': 'a b&c'},
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      final sent = transport.lastRequest!;
      expect(
        sent.headers['Content-Type'],
        startsWith('application/x-www-form-urlencoded'),
      );
      expect(
        Uri.splitQueryString(utf8.decode(transport.lastBody!)),
        {'user': 'ada', 'note': 'a b&c'},
      );
    });

    test('requestList decodes a list under dataKey', () async {
      transport.onGet(
        '/users',
        json: {
          'data': [
            {'id': 1, 'name': 'Ada'},
            {'id': 2, 'name': 'Linus'},
          ],
        },
      );

      final users = await manager.requestList<_UserModel>(
        path: '/users',
        method: RequestMethod.get,
        model: const _UserModel(),
      );

      expect(users.map((u) => u.id), [1, 2]);
    });

    test('access token is injected as Bearer on every request', () async {
      manager.setAccessToken('test-token');

      await manager.requestVoid(path: '/me', method: RequestMethod.get);

      expect(
        transport.lastRequest!.headers['Authorization'],
        'Bearer test-token',
      );
    });

    test('error responses decode into ApiException', () async {
      transport.onPost(
        '/users',
        status: 422,
        json: {'message': 'Validation failed', 'status': 422},
      );

      await expectLater(
        manager.requestVoid(path: '/users', method: RequestMethod.post),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.response)
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.message, 'message', 'Validation failed'),
        ),
      );
    });

    test('uploadRawData sends the bytes with the given content type', () async {
      await manager.uploadRawData<VoidModel>(
        path: '/upload',
        model: VoidModel(),
        data: const [1, 2, 3, 4],
        method: RequestMethod.put,
        contentType: 'image/png',
      );

      final sent = transport.lastRequest!;
      expect(sent.method, RawHttpMethod.put);
      expect(sent.body, isA<BytesRawHttpBody>());
      expect(transport.lastBody, [1, 2, 3, 4]);
      expect(sent.headers['Content-Type'], 'image/png');
    });

    test('uploadFormData sends a NetKitFormData body', () async {
      await manager.uploadFormData<VoidModel>(
        path: '/upload',
        model: VoidModel(),
        formData: NetKitFormData.fromMap({'field': 'value'}),
        method: RequestMethod.post,
      );

      final sent = transport.lastRequest!;
      expect(sent.body, isA<NetKitFormData>());
      expect((sent.body! as NetKitFormData).fields.single.key, 'field');
      expect(utf8.decode(transport.lastBody!), 'field=value\n');
    });

    test('uploadFile streams the file instead of reading it into memory',
        () async {
      final dir = await Directory.systemTemp.createTemp('net_kit_upload');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/blob.bin');
      final bytes = List<int>.generate(70 * 1024, (i) => i % 251);
      await file.writeAsBytes(bytes, flush: true);

      await manager.uploadFile<VoidModel>(
        path: '/upload',
        model: VoidModel(),
        filePath: file.path,
        method: RequestMethod.put,
      );

      final sent = transport.lastRequest!;
      expect(sent.body, isA<FileRawHttpBody>());
      expect(transport.lastBody, bytes);
      expect(sent.headers['Content-Type'], 'application/octet-stream');
    });

    test('per-request headers are preserved', () async {
      await manager.requestVoid(
        path: '/me',
        method: RequestMethod.get,
        headers: {'X-Trace': 'abc'},
      );

      expect(transport.lastRequest!.headers['X-Trace'], 'abc');
    });

    test('relative paths join a base URL that has a path segment', () async {
      final scoped = NetKitManager(
        baseUrl: 'https://api.example.com/v1',
        transport: transport,
      );
      addTearDown(scoped.dispose);

      await scoped.requestVoid(path: '/users', method: RequestMethod.get);
      await scoped.requestVoid(path: 'users', method: RequestMethod.get);

      expect(
        transport.requests.map((r) => r.uri.toString()),
        everyElement('https://api.example.com/v1/users'),
      );
    });

    test('absolute same-origin URL is preserved exactly', () async {
      const url = 'https://api.example.com/signed/object?X-Signature=abc&e=1';

      await manager.requestVoid(path: url, method: RequestMethod.put);

      expect(transport.lastRequest!.uri.toString(), url);
    });

    test('queryParameters with a list value repeat the key', () async {
      await manager.requestVoid(
        path: '/users',
        method: RequestMethod.get,
        queryParameters: {
          'ids': [1, 2],
          'q': 'x',
        },
      );

      expect(
        transport.lastRequest!.uri.toString(),
        'https://api.example.com/users?ids=1&ids=2&q=x',
      );
    });

    test('requestVoid accepts 204', () async {
      transport.onDelete('/users/1', status: 204);

      await expectLater(
        manager.requestVoid(path: '/users/1', method: RequestMethod.delete),
        completes,
      );
    });

    test('requestModel on 204 / empty body is a decoding error', () async {
      transport.onGet('/users/1', status: 204);

      await expectLater(
        manager.requestModel<_UserModel>(
          path: '/users/1',
          method: RequestMethod.get,
          model: const _UserModel(),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.decoding)
              .having((e) => e.statusCode, 'statusCode', 204)
              .having(
                (e) => e.message,
                'message',
                const NetKitErrorParams().emptyResponseBodyError,
              ),
        ),
      );
    });

    test('non-map body is a decoding error with 417', () async {
      transport.onGet('/users/1', json: [1, 2, 3]);

      await expectLater(
        manager.requestModel<_UserModel>(
          path: '/users/1',
          method: RequestMethod.get,
          model: const _UserModel(),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiFailureType.decoding)
              .having((e) => e.statusCode, 'statusCode', 417)
              .having(
                (e) => e.message,
                'message',
                const NetKitErrorParams().notMapTypeError,
              ),
        ),
      );
    });
  });
}
