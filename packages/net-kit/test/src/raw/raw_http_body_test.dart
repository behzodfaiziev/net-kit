import 'dart:convert';
import 'dart:io';

import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

Future<List<int>> collect(Stream<List<int>> stream) async {
  final out = <int>[];
  await for (final chunk in stream) {
    out.addAll(chunk);
  }
  return out;
}

void main() {
  group('RawHttpBody', () {
    test('StreamRawHttpBody keeps the stream and contentLength', () {
      final stream = Stream.fromIterable([
        [1, 2],
        [3],
      ]);
      final body = StreamRawHttpBody(stream: stream, contentLength: 3);

      expect(body.stream, same(stream));
      expect(body.contentLength, 3);
      expect(body.isReplayable, isFalse);
    });

    test('BytesRawHttpBody exposes the payload and is replayable', () {
      const bytes = [4, 5, 6];
      const body = BytesRawHttpBody(bytes);

      expect(body.bytes, bytes);
      expect(body.isReplayable, isTrue);
    });

    test('StringRawHttpBody exposes the payload and is replayable', () {
      const body = StringRawHttpBody('hello');

      expect(body.value, 'hello');
      expect(body.isReplayable, isTrue);
    });

    test('ReplayableRawHttpBody opens a fresh stream on every call', () async {
      var opens = 0;
      final body = ReplayableRawHttpBody(
        open: () {
          opens++;
          return Stream.fromIterable([
            [1, 2],
            [3],
          ]);
        },
        contentLength: 3,
      );

      expect(body.isReplayable, isTrue);
      expect(body.contentLength, 3);
      final first = body.open();
      final second = body.open();
      expect(first, isNot(same(second)));
      expect(await collect(first), [1, 2, 3]);
      expect(await collect(second), [1, 2, 3]);
      expect(opens, 2);
    });
  });

  group('FileRawHttpBody', () {
    late Directory tempDir;
    late File file;
    final payload = List<int>.generate(70 * 1024 + 3, (i) => i % 251);

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('net_kit_file_body');
      file = File('${tempDir.path}/payload.bin');
      await file.writeAsBytes(payload, flush: true);
    });

    tearDown(() => tempDir.delete(recursive: true));

    test('reads length and content from disk and is replayable', () async {
      final body = FileRawHttpBody(file.path);

      expect(body.isReplayable, isTrue);
      expect(body.path, file.path);
      expect(await body.length(), payload.length);
      expect(await collect(body.openRead()), payload);
      expect(await collect(body.openRead()), payload);
    });
  });

  group('NetKitMultipartFile', () {
    test('fromBytes streams the bytes with the given length', () async {
      final part = NetKitMultipartFile.fromBytes(
        [1, 2, 3],
        filename: 'a.bin',
        contentType: 'application/octet-stream',
      );

      expect(part.length, 3);
      expect(part.filename, 'a.bin');
      expect(part.contentType, 'application/octet-stream');
      expect(await collect(part.open()), [1, 2, 3]);
      expect(await collect(part.open()), [1, 2, 3]);
    });

    test('fromString encodes UTF-8 and defaults to text/plain', () async {
      final part = NetKitMultipartFile.fromString('héllo', filename: 'a.txt');

      expect(part.length, utf8.encode('héllo').length);
      expect(part.contentType, 'text/plain; charset=utf-8');
      expect(utf8.decode(await collect(part.open())), 'héllo');
      expect(
        NetKitMultipartFile.fromString('x', contentType: 'text/csv')
            .contentType,
        'text/csv',
      );
    });

    test('fromStream keeps the factory and metadata', () async {
      var opens = 0;
      final part = NetKitMultipartFile.fromStream(
        () {
          opens++;
          return Stream.value(const [7, 7]);
        },
        2,
        filename: 'two.bin',
      );

      expect(part.length, 2);
      expect(part.filename, 'two.bin');
      expect(part.contentType, isNull);
      await collect(part.open());
      await collect(part.open());
      expect(opens, 2);
    });

    test('fromPath reads the length and defaults filename to the base name',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('net_kit_part');
      addTearDown(() => tempDir.delete(recursive: true));
      final file = File('${tempDir.path}/report.pdf');
      await file.writeAsBytes([9, 8, 7, 6], flush: true);

      final part = await NetKitMultipartFile.fromPath(
        file.path,
        contentType: 'application/pdf',
      );

      expect(part.length, 4);
      expect(part.filename, 'report.pdf');
      expect(part.contentType, 'application/pdf');
      expect(await collect(part.open()), [9, 8, 7, 6]);
      expect(
        (await NetKitMultipartFile.fromPath(file.path, filename: 'x.pdf'))
            .filename,
        'x.pdf',
      );
    });
  });

  group('NetKitFormData', () {
    test('keeps ordered fields and files and is replayable', () {
      final part = NetKitMultipartFile.fromBytes([1]);
      final body = NetKitFormData(
        fields: const [MapEntry('a', '1'), MapEntry('a', '2')],
        files: [MapEntry('file', part)],
      );

      expect(body.isReplayable, isTrue);
      expect(body.fields.map((e) => '${e.key}=${e.value}'), ['a=1', 'a=2']);
      expect(body.files.single.key, 'file');
      expect(body.files.single.value, same(part));
    });

    test('fromMap converts scalars, repeats lists, skips null', () {
      final part = NetKitMultipartFile.fromBytes([1]);
      final body = NetKitFormData.fromMap({
        'name': 'report',
        'count': 2,
        'ratio': 0.5,
        'flag': true,
        'tags': ['x', 'y'],
        'missing': null,
        'file': part,
        'files': [part, part],
      });

      expect(
        body.fields.map((e) => '${e.key}=${e.value}'),
        [
          'name=report',
          'count=2',
          'ratio=0.5',
          'flag=true',
          'tags=x',
          'tags=y',
        ],
      );
      expect(body.files.map((e) => e.key), ['file', 'files', 'files']);
      expect(body.files.every((e) => identical(e.value, part)), isTrue);
    });

    test('fromMap rejects unsupported value types', () {
      expect(
        () => NetKitFormData.fromMap({'when': DateTime(2026)}),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'when'),
        ),
      );
      expect(
        () => NetKitFormData.fromMap({
          'nested': {'a': 1},
        }),
        throwsArgumentError,
      );
    });
  });
}
