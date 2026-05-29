import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/enum/http_status_codes.dart';
import 'package:test/test.dart';

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
    late DioAdapter adapter;

    setUp(() {
      manager = NetKitManager(
        baseUrl: 'https://example.com',
        dataKey: 'data',
      );
      adapter = DioAdapter(dio: manager);
      manager.httpClientAdapter = adapter;
    });

    tearDown(() {
      manager.dispose();
    });

    test('uploadFormData throws ApiException on non-2xx response', () async {
      adapter.onPost(
        '/upload',
        (server) => server.reply(
          HttpStatuses.badRequest.code,
          {'message': 'Validation failed'},
        ),
      );

      await expectLater(
        manager.uploadFormData(
          path: '/upload',
          model: const _UploadModel(),
          formData: FormData.fromMap({'field': 'value'}),
          method: RequestMethod.post,
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('uploadMultipartData throws ApiException on non-2xx response',
        () async {
      adapter.onPost(
        '/upload',
        (server) => server.reply(
          HttpStatuses.internalServerError.code,
          {'message': 'Server error'},
        ),
      );

      await expectLater(
        manager.uploadMultipartData(
          path: '/upload',
          model: const _UploadModel(),
          multipartFile: MultipartFile.fromString(
            'content',
            filename: 'file.txt',
          ),
          method: RequestMethod.post,
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('uploadRawData returns parsed model on success', () async {
      adapter.onPost(
        '/upload/raw',
        (server) => server.reply(
          HttpStatuses.ok.code,
          {
            'data': {'id': 42},
          },
        ),
        data: Matchers.any,
        headers: {'Content-Type': 'application/octet-stream'},
      );

      final result = await manager.uploadRawData(
        path: '/upload/raw',
        model: const _UploadModel(),
        data: [1, 2, 3, 4],
        method: RequestMethod.post,
      );

      expect(result.id, 42);
    });

    test('uploadRawData throws ApiException on non-2xx response', () async {
      adapter.onPost(
        '/upload/raw',
        (server) => server.reply(
          HttpStatuses.badRequest.code,
          {'message': 'Invalid payload'},
        ),
        data: Matchers.any,
        headers: {'Content-Type': 'application/octet-stream'},
      );

      await expectLater(
        manager.uploadRawData(
          path: '/upload/raw',
          model: const _UploadModel(),
          data: [1, 2, 3, 4],
          method: RequestMethod.post,
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
