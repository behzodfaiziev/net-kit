import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:net_kit/net_kit.dart';
import 'package:net_kit/net_kit_dio.dart';
import 'package:test/test.dart';

import '../../mocks/recording_http_client_adapter.dart';

void main() {
  late RecordingHttpClientAdapter adapter;
  late DioNetKitTransport client;

  RawHttpRequest put(RawHttpBody body) => RawHttpRequest(
        uri: Uri.parse('https://storage.example.com/objects/42'),
        method: RawHttpMethod.put,
        body: body,
      );

  String contentLength() =>
      adapter.lastOptions!.headers['content-length'].toString();

  setUp(() {
    adapter = RecordingHttpClientAdapter()
      ..drainStream = true
      ..collectBody = true;
    client = DioNetKitTransport(httpClientAdapter: adapter);
  });

  tearDown(() {
    client.close();
  });

  group('ReplayableRawHttpBody', () {
    test('is streamed in full on every send with Content-Length', () async {
      final payload = List<int>.generate(10 * 1024, (i) => i % 256);
      var opens = 0;
      final body = ReplayableRawHttpBody(
        open: () {
          opens++;
          return Stream<List<int>>.fromIterable([
            payload.sublist(0, 4096),
            payload.sublist(4096),
          ]);
        },
        contentLength: payload.length,
      );

      await client.send(put(body));
      expect(adapter.lastData, isA<Stream<List<int>>>());
      expect(adapter.bodyBytes, payload);
      expect(contentLength(), '${payload.length}');
      expect(opens, 1);

      adapter.bodyBytes.clear();
      await client.send(put(body));
      expect(adapter.requests, hasLength(2));
      expect(adapter.bodyBytes, payload);
      expect(contentLength(), '${payload.length}');
      expect(opens, 2);
    });
  });

  group('FileRawHttpBody', () {
    late Directory tempDir;
    late File file;
    late List<int> fileBytes;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('net_kit_file_upload');
      file = File('${tempDir.path}/report.pdf');
      final random = Random(11);
      fileBytes =
          List<int>.generate(200 * 1024 + 13, (_) => random.nextInt(256));
      await file.writeAsBytes(fileBytes, flush: true);
    });

    tearDown(() => tempDir.delete(recursive: true));

    test('sets Content-Length from the file and streams it', () async {
      final body = FileRawHttpBody(file.path);

      await client.send(put(body));

      expect(contentLength(), '${fileBytes.length}');
      expect(adapter.lastData, isA<Stream<List<int>>>());
      expect(adapter.lastData, isNot(isA<List<int>>()));
      expect(adapter.consumedChunks, greaterThan(1));
      expect(adapter.bodyBytes, fileBytes);
    });

    test('reopens the file on a second send', () async {
      final body = FileRawHttpBody(file.path);
      await client.send(put(body));
      adapter.bodyBytes.clear();

      await client.send(put(body));

      expect(adapter.requests, hasLength(2));
      expect(adapter.bodyBytes, fileBytes);
      expect(adapter.lastData, isNot(same(adapter.requests.first.data)));
    });
  });

  group('NetKitFormData', () {
    test('is sent as multipart with streamed file parts', () async {
      var opens = 0;
      final fileBytes = List<int>.generate(3000, (i) => (i * 7) % 256);
      final body = NetKitFormData(
        fields: const [MapEntry('title', 'Quarterly'), MapEntry('tag', 'a')],
        files: [
          MapEntry(
            'file',
            NetKitMultipartFile.fromStream(
              () {
                opens++;
                return Stream<List<int>>.fromIterable([
                  fileBytes.sublist(0, 1000),
                  fileBytes.sublist(1000),
                ]);
              },
              fileBytes.length,
              filename: 'report.bin',
              contentType: 'application/octet-stream',
            ),
          ),
        ],
      );

      await client.send(put(body));

      final sent = adapter.lastOptions!;
      expect(adapter.lastData, isA<FormData>());
      expect(
        sent.headers['content-type'].toString(),
        startsWith('multipart/form-data; boundary='),
      );
      final formData = adapter.lastData! as FormData;
      expect(formData.fields, [
        const MapEntry('title', 'Quarterly'),
        const MapEntry('tag', 'a'),
      ]);
      expect(formData.files.single.key, 'file');
      expect(formData.files.single.value.filename, 'report.bin');
      expect(formData.files.single.value.length, fileBytes.length);
      expect(
        formData.files.single.value.contentType.toString(),
        'application/octet-stream',
      );
      expect(opens, 1);

      final wire = latin1.decode(adapter.bodyBytes);
      expect(wire, contains('name="title"\r\n\r\nQuarterly'));
      expect(wire, contains('name="tag"\r\n\r\na'));
      expect(wire, contains('name="file"; filename="report.bin"'));
      expect(wire, contains('content-type: application/octet-stream'));
      expect(wire, contains(latin1.decode(fileBytes)));
      expect(adapter.consumedChunks, greaterThan(1));
    });

    test('a user Content-Type is replaced by the multipart one', () async {
      await client.send(
        RawHttpRequest(
          uri: Uri.parse('https://storage.example.com/objects/42'),
          method: RawHttpMethod.post,
          headers: const {'Content-Type': 'application/json'},
          body: const NetKitFormData(fields: [MapEntry('a', '1')]),
        ),
      );

      final headers = adapter.lastOptions!.headers;
      expect(
        headers['content-type'].toString(),
        startsWith('multipart/form-data; boundary='),
      );
      expect(headers.keys.where((k) => k.toLowerCase() == 'content-type'), [
        'content-type',
      ]);
    });

    test('sending the same body twice builds a fresh FormData each time',
        () async {
      var opens = 0;
      final body = NetKitFormData(
        fields: const [MapEntry('a', '1')],
        files: [
          MapEntry(
            'file',
            NetKitMultipartFile.fromStream(
              () {
                opens++;
                return Stream.value(const [1, 2, 3]);
              },
              3,
              filename: 'x.bin',
            ),
          ),
        ],
      );

      await client.send(put(body));
      final firstWire = List<int>.of(adapter.bodyBytes);
      final first = adapter.lastData! as FormData;
      adapter.bodyBytes.clear();

      await client.send(put(body));
      final second = adapter.lastData! as FormData;

      expect(second, isNot(same(first)));
      expect(opens, 2);
      expect(adapter.requests, hasLength(2));
      expect(latin1.decode(firstWire), contains('name="a"\r\n\r\n1'));
      expect(latin1.decode(adapter.bodyBytes), contains('name="a"\r\n\r\n1'));
      expect(latin1.decode(adapter.bodyBytes), contains('\u0001\u0002\u0003'));
    });
  });
}
