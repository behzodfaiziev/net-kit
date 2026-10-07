import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/core/net_kit_cancellation_token.dart';
import 'package:test/test.dart';

void main() {
  group('NetKitCancellationToken', () {
    test('RawHttpCancellationToken is an alias of the same type', () {
      final token = RawHttpCancellationToken();

      expect(token, isA<NetKitCancellationToken>());
      expect(RawHttpCancellationToken, NetKitCancellationToken);
    });

    test('isCancelled is false until cancel is called', () {
      final token = NetKitCancellationToken();

      expect(token.isCancelled, isFalse);
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('cancel is idempotent and notifies each binding once', () {
      final token = NetKitCancellationToken();
      var calls = 0;
      bindNetKitCancellationToken(token, () => calls++);

      token
        ..cancel()
        ..cancel();

      expect(calls, 1);
      expect(token.isCancelled, isTrue);
    });

    test('cancel reaches every concurrently bound request', () {
      final token = NetKitCancellationToken();
      final cancelled = <String>[];
      bindNetKitCancellationToken(token, () => cancelled.add('first'));
      bindNetKitCancellationToken(token, () => cancelled.add('second'));

      token.cancel();

      expect(cancelled, ['first', 'second']);
    });

    test('binding a cancelled token fires immediately', () {
      final token = NetKitCancellationToken()..cancel();
      var fired = false;

      final unbind = bindNetKitCancellationToken(token, () => fired = true);

      expect(fired, isTrue);
      expect(netKitCancellationBindingCount(token), 0);
      unbind();
    });

    test('unbind releases the callback so it is not invoked later', () {
      final token = NetKitCancellationToken();
      var fired = false;
      final unbind = bindNetKitCancellationToken(token, () => fired = true);

      unbind();
      token.cancel();

      expect(fired, isFalse);
      expect(netKitCancellationBindingCount(token), 0);
    });

    test('unbind of one request keeps the other bound', () {
      final token = NetKitCancellationToken();
      final cancelled = <String>[];
      final unbindFirst =
          bindNetKitCancellationToken(token, () => cancelled.add('first'));
      bindNetKitCancellationToken(token, () => cancelled.add('second'));

      unbindFirst();
      expect(netKitCancellationBindingCount(token), 1);
      token.cancel();

      expect(cancelled, ['second']);
    });

    test('cancel clears bindings and unbind afterwards is harmless', () {
      final token = NetKitCancellationToken();
      final unbind = bindNetKitCancellationToken(token, () {});

      token.cancel();
      expect(netKitCancellationBindingCount(token), 0);

      expect(unbind, returnsNormally);
      expect(netKitCancellationBindingCount(token), 0);
    });
  });
}
