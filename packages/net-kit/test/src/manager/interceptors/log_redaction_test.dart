import 'dart:convert';

import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/utility/log/log_redaction.dart';
import 'package:test/test.dart';

import '../../../mocks/fake_transport.dart';

const _signedUrl = 'https://storage.example.com/bucket/report.pdf'
    '?X-Goog-Algorithm=GOOG4-RSA-SHA256'
    '&X-Goog-Credential=svc%40example.iam%2F20260101%2Fauto'
    '&X-Goog-Date=20260101T000000Z'
    '&X-Goog-Expires=900'
    '&X-Goog-Signature=5ecre7519a7ure';

class _CapturingLogger implements INetKitLogger {
  final lines = <String>[];

  @override
  void trace(String message) => lines.add(message);

  @override
  void debug(String message) => lines.add(message);

  @override
  void info(String message) => lines.add(message);

  @override
  void warning(String message) => lines.add(message);

  @override
  void error(String? message) => lines.add('$message');

  @override
  void fatal(String? message) => lines.add('$message');
}

void main() {
  String redact(String url, [Iterable<String> extra = const []]) =>
      redactUriForLog(Uri.parse(url), {
        ...defaultSensitiveQueryParameters,
        ...extra.map((e) => e.toLowerCase()),
      });

  group('redactUriForLog', () {
    test('redacts the signature of a signed storage URL, keeps the rest', () {
      final logged = redact(_signedUrl);

      expect(logged, isNot(contains('5ecre7519a7ure')));
      expect(logged, isNot(contains('svc%40example')));
      expect(logged, contains('X-Goog-Signature=[REDACTED]'));
      expect(logged, contains('X-Goog-Credential=[REDACTED]'));
      expect(logged, contains('X-Goog-Date=20260101T000000Z'));
      expect(logged, contains('X-Goog-Expires=900'));
      expect(
        logged,
        startsWith('https://storage.example.com/bucket/report.pdf?'),
      );
    });

    test('redacts S3-style credentials', () {
      final logged = redact(
        'https://storage.example.com/o?X-Amz-Credential=AKIDEXAMPLE'
        '&X-Amz-Security-Token=session-secret&X-Amz-Signature=abc123'
        '&X-Amz-Expires=60',
      );

      expect(logged, isNot(contains('AKIDEXAMPLE')));
      expect(logged, isNot(contains('session-secret')));
      expect(logged, isNot(contains('abc123')));
      expect(logged, contains('X-Amz-Expires=60'));
    });

    test('redacts OAuth codes and tokens, case-insensitively', () {
      final logged = redact(
        'https://api.example.com/callback?Code=oauth-code&state=xyz'
        '&ACCESS_TOKEN=test-token&refresh_token=refresh-token&id_token=jwt'
        '&api_key=api-key&apiKey=api-key-2&sig=s1&secret=s2',
      );

      for (final secret in [
        'oauth-code',
        'test-token',
        'refresh-token',
        'jwt',
        'api-key',
        'api-key-2',
        's1',
        's2',
      ]) {
        expect(logged, isNot(contains('=$secret')));
      }
      expect(logged, contains('state=xyz'));
    });

    test('redacts tokens in the fragment and user-info', () {
      final logged = redact(
        'https://user:p4ssw0rd@api.example.com/cb#access_token=frag-token&x=1',
      );

      expect(logged, isNot(contains('p4ssw0rd')));
      expect(logged, isNot(contains('frag-token')));
      expect(logged, contains('[REDACTED]@api.example.com'));
      expect(logged, contains('x=1'));
    });

    test('custom names are matched after decoding', () {
      final logged = redact(
        'https://api.example.com/x?tenant%5Fsecret=abc&page=2',
        ['tenant_secret'],
      );

      expect(logged, isNot(contains('abc')));
      expect(logged, contains('page=2'));
    });

    test('URLs without secrets are unchanged', () {
      const url = 'https://api.example.com/users?page=2&sort=name#top';
      expect(redact(url), url);
    });
  });

  group('RedactingLogInterceptor', () {
    test('never prints a signed URL signature', () {
      final lines = <String>[];
      final interceptor = RedactingLogInterceptor(
        logPrint: (object) => lines.add('$object'),
      );
      final request = RawHttpRequest(
        uri: Uri.parse(_signedUrl),
        method: RawHttpMethod.put,
      );

      interceptor
        ..onRequest(request)
        ..onResponse(
          request,
          const RawHttpResponse(statusCode: 403, headers: {}),
        )
        ..onError(
          request,
          const ApiException(statusCode: 403, message: 'denied'),
        );

      final output = lines.join('\n');
      expect(output, isNot(contains('5ecre7519a7ure')));
      expect(output, contains('X-Goog-Signature=[REDACTED]'));
    });

    test('custom sensitiveQueryParameters are redacted', () {
      final lines = <String>[];
      RedactingLogInterceptor(
        sensitiveQueryParameters: const ['Session'],
        logPrint: (object) => lines.add('$object'),
      ).onRequest(
        RawHttpRequest(
          uri: Uri.parse('https://api.example.com/x?session=abc&page=1'),
          method: RawHttpMethod.get,
        ),
      );

      expect(lines.join('\n'), contains('session=[REDACTED]&page=1'));
    });
  });

  group('NetKitManager logs', () {
    test('a full authenticated flow leaks no credential into any log',
        () async {
      final printed = <String>[];
      final logger = _CapturingLogger();
      final transport = FakeTransport()
        ..on(RawHttpMethod.get, '/me', (request, _) {
          return request.headers['Authorization'] == 'Bearer new-token'
              ? FakeTransport.jsonResponse(
                  200,
                  {'accessToken': 'leaked-in-body'},
                  {
                    'set-cookie': ['sid=cookie-secret'],
                  },
                )
              : FakeTransport.jsonResponse(401, null);
        })
        ..onPost(
          '/auth/refresh',
          json: {'accessToken': 'new-token', 'refreshToken': 'next-refresh'},
        )
        ..onGet('/files', json: {'ok': true});
      final manager = NetKitManager(
        baseUrl: 'https://api.example.com',
        transport: transport,
        refreshTokenPath: '/auth/refresh',
        devMode: true,
        loggerEnabled: true,
        logger: logger,
        headers: {'X-Api-Key': 'api-key-secret', 'Cookie': 'sid=cookie-secret'},
        interceptors: [
          RedactingLogInterceptor(logPrint: (object) => printed.add('$object')),
        ],
      )
        ..setAccessToken('old-token')
        ..setRefreshToken('refresh-secret');
      addTearDown(manager.dispose);

      await manager.requestModel<_Any>(
        path: '/me',
        method: RequestMethod.get,
        model: const _Any(),
      );
      await manager.requestVoid(
        path: '/files?signature=sig-secret&code=oauth-secret&page=3',
        method: RequestMethod.get,
      );

      final output = [...printed, ...logger.lines].join('\n');
      for (final secret in [
        'old-token',
        'new-token',
        'refresh-secret',
        'next-refresh',
        'api-key-secret',
        'cookie-secret',
        'leaked-in-body',
        'sig-secret',
        'oauth-secret',
      ]) {
        expect(output, isNot(contains(secret)), reason: secret);
      }
      expect(output, contains('Authorization: [REDACTED]'));
      expect(output, contains('page=3'));
      // The refresh request body (carrying the refresh token) is never logged.
      expect(
        transport.bodies.whereType<List<int>>().map(utf8.decode),
        contains(contains('refresh-secret')),
      );
    });
  });
}

class _Any extends INetKitModel {
  const _Any();

  @override
  _Any fromJson(Map<String, dynamic> json) => const _Any();

  @override
  Map<String, dynamic>? toJson() => null;
}
