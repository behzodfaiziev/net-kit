import 'dart:convert';

import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

void main() {
  group('RawHttpResponse', () {
    test('header lookup is case-insensitive', () {
      const response = RawHttpResponse(
        statusCode: 308,
        headers: {
          'Range': ['bytes=0-8388607'],
        },
      );

      expect(response.header('Range'), 'bytes=0-8388607');
      expect(response.header('range'), 'bytes=0-8388607');
      expect(response.header('RANGE'), 'bytes=0-8388607');
    });

    test('missing header returns null', () {
      const response = RawHttpResponse(statusCode: 200, headers: {});

      expect(response.header('ETag'), isNull);
    });

    test('empty header values return null', () {
      const response = RawHttpResponse(
        statusCode: 200,
        headers: {
          'ETag': <String>[],
        },
      );

      expect(response.header('ETag'), isNull);
    });

    test('header returns the first of repeated values, not a join', () {
      const response = RawHttpResponse(
        statusCode: 200,
        headers: {
          'Accept-Ranges': ['bytes', 'none'],
        },
      );

      expect(response.header('Accept-Ranges'), 'bytes');
    });

    test('headerValues returns every repeated value unjoined', () {
      const response = RawHttpResponse(
        statusCode: 200,
        headers: {
          'Set-Cookie': ['a=1; Path=/', 'b=2; HttpOnly'],
        },
      );

      expect(
        response.headerValues('set-cookie'),
        ['a=1; Path=/', 'b=2; HttpOnly'],
      );
      expect(response.headerValues('X-Missing'), isEmpty);
    });

    test('headerValues is unmodifiable', () {
      const response = RawHttpResponse(
        statusCode: 200,
        headers: {
          'ETag': ['"v1"'],
        },
      );

      expect(
        () => response.headerValues('ETag').add('x'),
        throwsUnsupportedError,
      );
    });

    test('contentLength parses the header and is null when unusable', () {
      RawHttpResponse withLength(String? value) => RawHttpResponse(
            statusCode: 200,
            headers: {
              if (value != null) 'Content-Length': [value],
            },
          );

      expect(withLength('8388608').contentLength, 8388608);
      expect(withLength(' 12 ').contentLength, 12);
      expect(withLength('many').contentLength, isNull);
      expect(withLength(null).contentLength, isNull);
    });

    test('isSuccessful is true only for 2xx', () {
      bool ok(int status) =>
          RawHttpResponse(statusCode: status, headers: const {}).isSuccessful;

      expect(ok(200), isTrue);
      expect(ok(204), isTrue);
      expect(ok(299), isTrue);
      expect(ok(199), isFalse);
      expect(ok(300), isFalse);
      expect(ok(308), isFalse);
      expect(ok(404), isFalse);
      expect(ok(500), isFalse);
    });

    test('bodyBytes defaults to empty and bodyText decodes UTF-8', () {
      const empty = RawHttpResponse(statusCode: 204, headers: {});
      final text = RawHttpResponse(
        statusCode: 200,
        headers: const {},
        bodyBytes: utf8.encode('{"name":"héllo"}'),
      );
      const malformed = RawHttpResponse(
        statusCode: 200,
        headers: {},
        bodyBytes: [0x61, 0xff, 0x62],
      );

      expect(empty.bodyBytes, isEmpty);
      expect(empty.bodyText, '');
      expect(text.bodyText, '{"name":"héllo"}');
      expect(malformed.bodyText, 'a\u{FFFD}b');
    });

    test('stores protocol statuses without classifying success', () {
      const statuses = [308, 401, 404, 410, 500];

      for (final status in statuses) {
        final response = RawHttpResponse(
          statusCode: status,
          headers: const {},
        );
        expect(response.statusCode, status);
      }
    });
  });

  group('RawHttpStreamedResponse', () {
    final body = Stream<List<int>>.value(const [1, 2, 3]);
    final response = RawHttpStreamedResponse(
      statusCode: 206,
      headers: const {
        'Content-Length': ['3'],
        'Content-Range': ['bytes 0-2/10'],
        'Set-Cookie': ['a=1', 'b=2'],
      },
      body: body,
    );

    test('exposes the body stream as given', () {
      expect(response.body, same(body));
    });

    test('shares the header helpers with RawHttpResponse', () {
      expect(response.isSuccessful, isTrue);
      expect(response.contentLength, 3);
      expect(response.header('content-range'), 'bytes 0-2/10');
      expect(response.header('set-cookie'), 'a=1');
      expect(response.headerValues('SET-COOKIE'), ['a=1', 'b=2']);
      expect(response.headerValues('x-missing'), isEmpty);
      expect(response.header('x-missing'), isNull);
    });

    test('non-2xx is still a response', () {
      const notFound = RawHttpStreamedResponse(
        statusCode: 404,
        headers: {},
        body: Stream.empty(),
      );

      expect(notFound.isSuccessful, isFalse);
      expect(notFound.contentLength, isNull);
    });
  });
}
