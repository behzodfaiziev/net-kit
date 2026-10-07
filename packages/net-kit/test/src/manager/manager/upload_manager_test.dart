import 'dart:convert';

import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/enum/http_status_codes.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

class _UploadModel extends INetKitModel {
  const _UploadModel({this.id});

  final int? id;

  @override
  _UploadModel fromJson(Map<String, dynamic> json) {
    return _UploadModel(id: json['id'] as int?);
  }

  @override
  Map<String, dynamic>? toJson() => {'id': id};
}

void main() {
  group('UploadManagerMixin', () {
    late NetKitManager manager;
    late FakeTransport transport;

    setUp(() {
      transport = FakeTransport();
      manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: transport,
        dataKey: 'data',
      );
    });

    tearDown(() {
      manager.dispose();
    });

    test('uploadFormData throws ApiException on non-2xx response', () async {
      transport.onPost(
        '/upload',
        status: HttpStatuses.badRequest.code,
        json: {'message': 'Validation failed'},
      );

      await expectLater(
        manager.uploadFormData(
          path: '/upload',
          model: const _UploadModel(),
          formData: NetKitFormData.fromMap({'field': 'value'}),
          method: RequestMethod.post,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'Validation failed'),
        ),
      );
    });

    test('uploadFormData sends NetKitFormData with fields in order', () async {
      transport.onPost(
        '/upload',
        json: {
          'data': {'id': 1},
        },
      );

      await manager.uploadFormData(
        path: '/upload',
        model: const _UploadModel(),
        formData: NetKitFormData.fromMap({
          'tag': ['a', 'b'],
          'name': 'x',
          'tag2': 'c',
        }),
        method: RequestMethod.post,
      );

      final body = transport.lastRequest!.body;
      expect(body, isA<NetKitFormData>());
      final form = body! as NetKitFormData;
      expect(
        form.fields.map((e) => '${e.key}=${e.value}'),
        ['tag=a', 'tag=b', 'name=x', 'tag2=c'],
      );
      expect(form.files, isEmpty);
      // The transport owns the multipart boundary, so the manager sets none.
      expect(
        transport.lastRequest!.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('content-type')),
      );
    });

    test('uploadMultipartData throws ApiException on non-2xx response',
        () async {
      transport.onPost(
        '/upload',
        status: HttpStatuses.internalServerError.code,
        json: {'message': 'Server error'},
      );

      await expectLater(
        manager.uploadMultipartData(
          path: '/upload',
          model: const _UploadModel(),
          multipartFile: NetKitMultipartFile.fromString(
            'content',
            filename: 'file.txt',
          ),
          method: RequestMethod.post,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('uploadMultipartData sends the part under the default field name',
        () async {
      transport.onPost(
        '/upload',
        json: {
          'data': {'id': 7},
        },
      );

      final result = await manager.uploadMultipartData(
        path: '/upload',
        model: const _UploadModel(),
        multipartFile: NetKitMultipartFile.fromString(
          'content',
          filename: 'file.txt',
        ),
        method: RequestMethod.post,
      );

      expect(result.id, 7);
      final body = transport.lastRequest!.body;
      expect(body, isA<NetKitFormData>());
      final form = body! as NetKitFormData;
      expect(form.fields, isEmpty);
      expect(form.files, hasLength(1));
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'file.txt');
      expect(form.files.single.value.length, utf8.encode('content').length);
      expect(
        utf8.decode(transport.lastBody!),
        contains('file:file.txt:content'),
      );
    });

    test('uploadMultipartData honours a custom fieldName', () async {
      transport.onPost('/upload', json: {'data': <String, dynamic>{}});

      await manager.uploadMultipartData(
        path: '/upload',
        model: const _UploadModel(),
        multipartFile: NetKitMultipartFile.fromBytes(
          [1, 2, 3],
          filename: 'blob.bin',
        ),
        method: RequestMethod.post,
        fieldName: 'attachment',
      );

      final form = transport.lastRequest!.body! as NetKitFormData;
      expect(form.files.single.key, 'attachment');
    });

    test('uploadRawData returns parsed model on success', () async {
      transport.onPost(
        '/upload/raw',
        json: {
          'data': {'id': 42},
        },
      );

      final result = await manager.uploadRawData(
        path: '/upload/raw',
        model: const _UploadModel(),
        data: [1, 2, 3, 4],
        method: RequestMethod.post,
      );

      expect(result.id, 42);
    });

    test('uploadRawData sends exactly the given bytes with Content-Type',
        () async {
      transport.onPost(
        '/upload/raw',
        json: {
          'data': {'id': 1},
        },
      );

      await manager.uploadRawData(
        path: '/upload/raw',
        model: const _UploadModel(),
        data: [1, 2, 3, 4],
        method: RequestMethod.post,
      );

      final request = transport.lastRequest!;
      expect(request.method, RawHttpMethod.post);
      expect(request.uri.toString(), 'https://api.example.com/upload/raw');
      expect(request.body, isA<BytesRawHttpBody>());
      expect(transport.lastBody, [1, 2, 3, 4]);
      expect(request.headers['Content-Type'], 'application/octet-stream');
    });

    test('uploadRawData uses the given contentType', () async {
      transport.onPut('/upload/raw', json: {'data': <String, dynamic>{}});

      await manager.uploadRawData(
        path: '/upload/raw',
        model: const _UploadModel(),
        data: utf8.encode('hello'),
        method: RequestMethod.put,
        contentType: 'text/plain',
      );

      expect(transport.lastRequest!.headers['Content-Type'], 'text/plain');
      expect(utf8.decode(transport.lastBody!), 'hello');
    });

    test('uploadRawData throws ApiException on non-2xx response', () async {
      transport.onPost(
        '/upload/raw',
        status: HttpStatuses.badRequest.code,
        json: {'message': 'Invalid payload'},
      );

      await expectLater(
        manager.uploadRawData(
          path: '/upload/raw',
          model: const _UploadModel(),
          data: [1, 2, 3, 4],
          method: RequestMethod.post,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'Invalid payload'),
        ),
      );
    });
  });
}
