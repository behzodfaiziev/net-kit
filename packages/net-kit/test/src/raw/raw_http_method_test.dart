import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

void main() {
  group('RawHttpMethod', () {
    test('maps to upper-case HTTP names', () {
      expect(RawHttpMethod.get.httpName, 'GET');
      expect(RawHttpMethod.post.httpName, 'POST');
      expect(RawHttpMethod.put.httpName, 'PUT');
      expect(RawHttpMethod.patch.httpName, 'PATCH');
      expect(RawHttpMethod.delete.httpName, 'DELETE');
      expect(RawHttpMethod.head.httpName, 'HEAD');
      expect(RawHttpMethod.options.httpName, 'OPTIONS');
    });

    test('includes the seven standard methods', () {
      expect(RawHttpMethod.values, hasLength(7));
    });
  });
}
