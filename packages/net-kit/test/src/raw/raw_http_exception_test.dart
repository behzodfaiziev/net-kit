import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

void main() {
  group('RawHttpException', () {
    test('carries message, type, cause, and uri', () {
      final uri = Uri.parse('https://storage.example.com/upload');
      const cause = FormatException('boom');
      final exception = RawHttpException(
        message: 'timed out',
        type: RawHttpFailureType.timeout,
        cause: cause,
        uri: uri,
      );

      expect(exception.message, 'timed out');
      expect(exception.type, RawHttpFailureType.timeout);
      expect(exception.cause, same(cause));
      expect(exception.uri, uri);
      expect(
        exception.toString(),
        'RawHttpException(RawHttpFailureType.timeout): timed out',
      );
    });

    test('cause and uri are optional', () {
      const exception = RawHttpException(
        message: 'failed',
        type: RawHttpFailureType.unknown,
      );

      expect(exception.cause, isNull);
      expect(exception.uri, isNull);
    });

    test('is not an ApiException', () {
      const exception = RawHttpException(
        message: 'failed',
        type: RawHttpFailureType.unknown,
      );

      expect(exception, isA<Exception>());
      expect(exception, isNot(isA<ApiException>()));
    });
  });

  group('RawHttpFailureType', () {
    test('covers transport failures only, never HTTP statuses', () {
      expect(RawHttpFailureType.values, [
        RawHttpFailureType.timeout,
        RawHttpFailureType.connection,
        RawHttpFailureType.tls,
        RawHttpFailureType.cancellation,
        RawHttpFailureType.invalidResponse,
        RawHttpFailureType.unknown,
      ]);
    });
  });
}
