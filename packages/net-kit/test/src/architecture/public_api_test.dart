import 'dart:io';

import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

import '../../mocks/fake_transport.dart';

/// Source-level guards for the v6 boundary: the main entrypoint exposes only
/// net_kit-owned types, and the Dio adapter lives behind `net_kit_dio.dart`.
void main() {
  final libDir = Directory('lib');

  /// Every library reachable from [entry] through `export` directives,
  /// including their `part` files.
  Set<File> reachable(File entry) {
    final seen = <String>{};
    final files = <File>{};
    void visit(File file) {
      if (!seen.add(file.path)) {
        return;
      }
      files.add(file);
      final source = file.readAsStringSync();
      for (final match
          in RegExp(r"""^(export|part)\s+'([^']+)'""", multiLine: true)
              .allMatches(source)) {
        final target = match.group(2)!;
        if (target.startsWith('package:') || target.startsWith('dart:')) {
          continue;
        }
        visit(File(Uri.file(file.path).resolve(target).toFilePath()));
      }
    }

    visit(entry);
    return files;
  }

  group('package:net_kit/net_kit.dart', () {
    final entry = File('lib/net_kit.dart');

    test('does not export package:dio', () {
      expect(entry.readAsStringSync(), isNot(contains('package:dio')));
    });

    test('no exported library (or its parts) imports package:dio', () {
      final leaks = <String>[];
      for (final file in reachable(entry)) {
        final source = file.readAsStringSync();
        if (RegExp(r"""^\s*(import|export)\s+'package:dio/""", multiLine: true)
            .hasMatch(source)) {
          leaks.add(file.path);
        }
      }
      expect(leaks, isEmpty, reason: 'Dio must stay behind net_kit_dio.dart');
    });

    test('exported sources never mention Dio exception or option types', () {
      final forbidden = RegExp(
        r'\b(DioException|DioExceptionType|RequestOptions|BaseOptions|'
        'CancelToken|MultipartFile|FormData|HttpClientAdapter|'
        r'InterceptorsWrapper|LogInterceptor)\b',
      );
      final hits = <String>[];
      for (final file in reachable(entry)) {
        final source = file.readAsStringSync();
        // Dartdoc may name Dio types when explaining the migration, so only
        // code lines count.
        final code = source
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('///'))
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        if (forbidden.hasMatch(code)) {
          hits.add(file.path);
        }
      }
      expect(hits, isEmpty);
    });

    test('generic raw HTTP layer does not depend on Dio', () {
      final leaks = <String>[];
      for (final entity in Directory('lib/src/raw').listSync()) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        if (entity.readAsStringSync().contains('package:dio/')) {
          leaks.add(entity.path);
        }
      }
      expect(leaks, isEmpty);
    });

    test('NetKitManager composes a NetKitTransport without Dio', () async {
      final transport = FakeTransport()..onGet('/ping', json: {'ok': true});
      final manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: transport,
      );
      addTearDown(manager.dispose);

      await manager.requestVoid(path: '/ping', method: RequestMethod.get);

      expect(identical(manager.transport, transport), isTrue);
      expect(
        transport.requests.single.uri.toString(),
        'https://api.example.com/ping',
      );
      expect(transport.requests.single, isA<RawHttpRequest>());
    });

    test('RawHttpClient is the transport contract', () {
      final NetKitTransport transport = FakeTransport();
      expect(transport, isA<RawHttpClient>());
    });
  });

  group('package:net_kit/net_kit_dio.dart', () {
    test('is the only entrypoint that exposes Dio', () {
      final dioEntry = File('lib/net_kit_dio.dart').readAsStringSync();
      expect(dioEntry, contains("export 'package:dio/dio.dart'"));
      expect(dioEntry, contains('dio_net_kit_transport.dart'));

      final entrypoints = libDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.path.split(Platform.pathSeparator).last)
          .toSet();
      expect(entrypoints, {'net_kit.dart', 'net_kit_dio.dart'});
    });
  });
}
