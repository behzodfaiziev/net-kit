# Migration Guidance

# Migrating from 5.x to 6.0

6.0 is a breaking release with one theme: **the net_kit public API is no longer Dio's public
API.** `package:net_kit/net_kit.dart` exports only net_kit-owned types. Dio is still the default
transport, but it is an adapter behind `NetKitTransport`, reachable through
`package:net_kit/net_kit_dio.dart` when you need it.

## Checklist

1. Remove `import 'package:dio/dio.dart';` from code that only used it for net_kit types. If you
   still need Dio itself, import `package:net_kit/net_kit_dio.dart` (it re-exports Dio).
2. Replace the two auth booleans with `authPolicy` (table below).
3. Replace `options: Options(...)` with `headers:` / `timeout:`, and `cancelToken: CancelToken()`
   with `cancellationToken: NetKitCancellationToken()`.
4. Replace Dio `FormData` / `MultipartFile` with `NetKitFormData` / `NetKitMultipartFile`.
5. Update the `NetKitManager` constructor (`baseOptions`, `httpClientAdapter`, `interceptor`,
   `testMode`).
6. Decide whether any request legitimately targets another origin; the default now blocks it.
7. Replace `onRefreshFailed` with `onSessionInvalidated` and move sign-out logic there (see
   "Session invalidation" below).

## Breaking-change ledger

| 5.x | 6.0 |
|-----|-----|
| `export 'package:dio/dio.dart'` from `net_kit.dart` | Removed. `package:net_kit/net_kit_dio.dart` re-exports Dio and exposes the adapter |
| `NetKitManager(baseOptions: BaseOptions(headers: h, connectTimeout: c, receiveTimeout: r))` | `NetKitManager(headers: h, timeout: NetKitTimeout(connect: c, receive: r))` |
| `NetKitManager(httpClientAdapter: adapter)` | `NetKitManager(transport: DioNetKitTransport(httpClientAdapter: adapter))` (from `net_kit_dio.dart`) or any `NetKitTransport` |
| `NetKitManager(interceptor: Interceptor)` | `NetKitManager(interceptors: [NetKitInterceptor])` |
| `NetKitManager(testMode: ...)` (deprecated) | Removed; use `devMode` |
| `NetKitManager(allowCrossOriginRequests: true)` default | Default is `false`. When `true`, cross-origin requests are sent **without** stored headers or the access token |
| `manager.baseOptions`, `parameters.baseOptions`, `manager.interceptors`, `manager.httpClientAdapter` | `parameters.headers`, `parameters.timeout`, `parameters.interceptors`, `manager.transport` |
| `options: Options(headers: {...}, receiveTimeout: t)` | `headers: {...}, timeout: NetKitTimeout(receive: t)` |
| `cancelToken: CancelToken()` | `cancellationToken: NetKitCancellationToken()` (shared across requests, idempotent) |
| `ProgressCallback` | `NetKitProgressCallback` (same signature) |
| `containsAccessToken` / `skipTokenRefresh` | `authPolicy: AuthPolicy` (see below) |
| `uploadFormData(formData: FormData)` | `uploadFormData(formData: NetKitFormData)` |
| `uploadMultipartData(multipartFile: MultipartFile)` | `uploadMultipartData(multipartFile: NetKitMultipartFile, fieldName: 'file')` |
| `uploadFormData(..., contentType: ...)` / `uploadMultipartData(..., contentType: ...)` | Removed; the transport sets `multipart/form-data; boundary=...` |
| `uploadFile` buffers the file (`readAsBytes`) | `uploadFile` streams the file and reopens it on retry |
| `onRefreshFailed: ({int? statusCode, DioException exception})`, called for every refresh failure | Removed. `onSessionInvalidated: (ApiException exception)` is called only when the refresh endpoint answers 401; other refresh failures reach the caller with their own `ApiFailureType` and `fromRefresh == true` |
| `removeAccessTokenBeforeRefresh` deleted the stored access token before refreshing | It only omits the header from the refresh request; the stored token is kept if the refresh fails |
| Logged URLs include the query string | Credential-like query parameters (`token`, `access_token`, `code`, `signature`, `X-Amz-Signature`, ...) are redacted; add names with `sensitiveQueryParameters` |
| `on DioException catch` anywhere around net_kit | Not needed: only `ApiException` (with `type`) escapes `NetKitManager`; only `RawHttpException` escapes the transport |
| `RequestExtraKeys` | Removed (was Dio `extra` plumbing) |
| `RefreshTokenContentType` in `request_extra_keys.dart` | Same enum, still exported from `net_kit.dart` |
| 401 with no `refreshTokenPath` → "Refresh token path is not set" error | The `401` is returned as an `ApiException(statusCode: 401)` |
| `RawHttpClient` interface, `DioRawHttpClient()` from `net_kit.dart` | `RawHttpClient` = `NetKitTransport`; `DioRawHttpClient` = `DioNetKitTransport` from `net_kit_dio.dart`, or use `manager.transport` |
| `RawHttpRequest(connectTimeout:, sendTimeout:, receiveTimeout:)` | `RawHttpRequest(timeout: NetKitTimeout(connect:, send:, receive:))` |
| `RawHttpResponse.body` (`Object?`) | `RawHttpResponse.bodyBytes` (`List<int>`), plus `bodyText` |
| `RawHttpResponse.header(name)` comma-joins repeats | Returns the first value; use `headerValues(name)` for repeats |
| `RawHttpFailureType.connection` for certificate errors, `unknown` for a missing status | `tls` and `invalidResponse` |
| `DioRawHttpClient.test(httpClientAdapter:)` | `DioNetKitTransport(httpClientAdapter:)` |

## Auth policy

```dart
// 5.x                                             // 6.0
containsAccessToken: null / true                   authPolicy: AuthPolicy.inherit   // default
containsAccessToken: false, skipTokenRefresh: true authPolicy: AuthPolicy.none
containsAccessToken: false                         authPolicy: AuthPolicy.none      // see note
skipTokenRefresh: true                             authPolicy: AuthPolicy.none      // see note
(no equivalent)                                    authPolicy: AuthPolicy.required
```

Note: in 5.x the two flags were independent, so `containsAccessToken: false` alone still refreshed
on `401`, and `skipTokenRefresh: true` alone still sent the token. 6.0 has no such split states:
`none` means "public endpoint" (no token, no refresh). If you relied on "send the token but never
refresh", handle the `401` yourself: with `AuthPolicy.inherit` the manager refreshes once and
retries; a second `401` is returned to you.

`AuthPolicy.required` is new: the request fails before sending with
`ApiException(type: ApiFailureType.auth, statusCode: 401)` when no access token is stored.

## Before / after

### Constructor

```dart
// 5.x
final manager = NetKitManager(
  baseUrl: 'https://api.example.com',
  baseOptions: BaseOptions(
    headers: {'Accept-Language': 'en'},
    connectTimeout: const Duration(seconds: 10),
  ),
  interceptor: MyDioInterceptor(),
  refreshTokenPath: '/auth/refresh',
);

// 6.0
final manager = NetKitManager(
  baseUrl: 'https://api.example.com',
  headers: {'Accept-Language': 'en'},
  timeout: const NetKitTimeout(connect: Duration(seconds: 10)),
  interceptors: [MyInterceptor()],
  refreshTokenPath: '/auth/refresh',
);
```

### Request

```dart
// 5.x
await manager.requestModel<UserModel>(
  path: '/me',
  method: RequestMethod.get,
  model: const UserModel(),
  options: Options(headers: {'X-Trace': traceId}),
  cancelToken: cancelToken,
);

// 6.0
await manager.requestModel<UserModel>(
  path: '/me',
  method: RequestMethod.get,
  model: const UserModel(),
  headers: {'X-Trace': traceId},
  cancellationToken: token, // NetKitCancellationToken
);
```

### Public endpoint

```dart
// 5.x
await manager.requestModel<SessionModel>(
  path: '/auth/login',
  method: RequestMethod.post,
  model: const SessionModel(),
  body: credentials,
  containsAccessToken: false,
  skipTokenRefresh: true,
);

// 6.0
await manager.requestModel<SessionModel>(
  path: '/auth/login',
  method: RequestMethod.post,
  model: const SessionModel(),
  body: credentials,
  authPolicy: AuthPolicy.none,
);
```

### Multipart upload

```dart
// 5.x
await manager.uploadFormData<VoidModel>(
  path: '/documents',
  model: VoidModel(),
  method: RequestMethod.post,
  formData: FormData.fromMap({
    'title': 'Report',
    'file': await MultipartFile.fromFile(path, filename: 'report.pdf'),
  }),
);

// 6.0
await manager.uploadFormData<VoidModel>(
  path: '/documents',
  model: VoidModel(),
  method: RequestMethod.post,
  formData: NetKitFormData.fromMap({
    'title': 'Report',
    'file': await NetKitMultipartFile.fromPath(path, filename: 'report.pdf'),
  }),
);
```

### Interceptor

```dart
// 5.x
class TraceInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-Trace'] = newTraceId();
    handler.next(options);
  }
}

// 6.0
class TraceInterceptor extends NetKitInterceptor {
  const TraceInterceptor();

  @override
  RawHttpRequest onRequest(RawHttpRequest request) {
    return request.copyWith(
      headers: {...request.headers, 'X-Trace': newTraceId()},
    );
  }
}
```

### Session invalidation (replaces `onRefreshFailed`)

In 5.x `onRefreshFailed` fired for **every** refresh failure, so apps that signed the user out
there also signed them out when the device was offline or the server returned `503`. 6.0 removes
it and separates the cases:

```dart
// 5.x
onRefreshFailed: ({required int? statusCode, required DioException exception}) {
  logout(); // also ran for offline, timeouts, 5xx, ...
}

// 6.0
onSessionInvalidated: (ApiException exception) {
  logout(); // only when the refresh endpoint answered 401
}
```

| Refresh outcome | Tokens | `onSessionInvalidated` | Caller receives |
|-----------------|--------|------------------------|-----------------|
| Refresh endpoint `401` | cleared | called once | `sessionInvalidated` (401) |
| Offline, DNS, TLS | kept | not called | `transport`, `fromRefresh` |
| Timeout | kept | not called | `timeout`, `fromRefresh` |
| `400`, `403`, `429`, `5xx`, other statuses | kept | not called | `response` with the status, `fromRefresh` |
| Malformed body, `2xx` without access token | kept | not called | `decoding`, `fromRefresh` |

If you want to react to non-terminal refresh failures (for example to show "offline"), check
`ApiException.fromRefresh` and `type` where you handle request errors, or in a
`NetKitInterceptor.onError`.

### Raw client

```dart
// 5.x
final RawHttpClient raw = DioRawHttpClient();

// 6.0 — option A: share the manager's transport (it carries no auth state)
final RawHttpClient raw = manager.transport;

// 6.0 — option B: construct the adapter explicitly
import 'package:net_kit/net_kit_dio.dart';
final RawHttpClient raw = DioNetKitTransport();
```

### Errors

`ApiException.type` tells you what happened; the status codes outside `response` are synthetic:

| `type` | `statusCode` | When |
|--------|--------------|------|
| `response` | HTTP status | The server answered with a non-2xx status |
| `transport` | `503` | Offline, DNS, socket, TLS, or an unusable transport response |
| `timeout` | `408` | Connect, send, or receive timeout |
| `cancelled` | `null` | The cancellation token was cancelled |
| `auth` | `401` | Token required but missing, or a `401` could not be retried after a successful refresh |
| `sessionInvalidated` | `401` | The refresh endpoint answered `401`; tokens were cleared and `onSessionInvalidated` ran |
| `decoding` | HTTP status or `417` | Empty body, non-map body, model parsing failure |
| `invalidRequest` | `400` or redirect status | Cross-origin blocked, too many redirects, non-replayable body on replay |
| `unknown` | `500` | Any other exception while performing the request |

## Origin and redirect policy

`NetKitManager` now treats its base URL's origin as a trust boundary:

- Absolute `path`s on another origin fail with `crossOriginRequestBlockedError` unless
  `allowCrossOriginRequests: true`. Even then the stored headers and the access token are **not**
  sent; only per-request headers are.
- The manager follows up to five redirects itself. Same-origin redirects keep headers. A redirect
  to another origin is blocked by default; when allowed, stored and sensitive headers are stripped.
  `303` and `301`/`302` after `POST` become body-less `GET`; `307`/`308` keep the method and body.
- The raw transport never follows redirects unless `RawHttpRequest(followRedirects: true)`.

For signed storage URLs use the transport directly (`manager.transport.send(RawHttpRequest(...))`).

## Raw transport hardening: v5.5.0

No breaking changes. Everything below is additive or behavior-preserving.

### Dio 5.10+ works without an override

The 5.5.0 pre-releases did not compile against Dio 5.10 because `DioExceptionType.transformTimeout`
was missing from an exhaustive switch. 5.5.0 classifies Dio failure types through a lookup with a
tolerant fallback, so any `dependency_overrides: dio` pin added for that reason can be removed.
`transformTimeout` maps to `RawHttpFailureType.timeout`.

### Development log output changed

`logInterceptorEnabled: true` now registers Net-Kit's redacting log interceptor instead of Dio's
`LogInterceptor`. The format is similar (URL, method, status, headers) but secret header values
print as `[REDACTED]` and bodies are never printed. Add header names with
`NetKitManager(sensitiveHeaders: [...])`. If you relied on seeing raw `Authorization` values in
logs, add your own interceptor instead.

### Optional origin enforcement

```dart
NetKitManager(
  baseUrl: 'https://api.example.com',
  allowCrossOriginRequests: false, // default: true
);
```

When `false`, absolute URLs on another origin fail with `ApiException` (status 400,
`NetKitErrorParams.crossOriginRequestBlockedError`) before sending. Use `RawHttpClient` for
external URLs such as signed storage uploads.

### Raw transport additions

- `RawHttpMethod.options`
- `RawHttpResponse.headerValues(name)` for repeated headers such as `Set-Cookie`
- `RawHttpCancellationToken` may be shared across concurrent requests; `cancel()` cancels all of them
- `uploadFile` is documented as buffering the whole file; stream large files with
  `RawHttpClient` + `StreamRawHttpBody(stream: File(path).openRead(), contentLength: size)`

## Auth refresh hardening: v5.4.0

### New per-request flags

All request methods accept optional auth/retry flags (defaults preserve prior behavior):

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `skipTokenRefresh` | `false` | When `true`, a 401 does **not** trigger automatic refresh |
| `allowRetryOn401` | `false` | When `true`, POST/PATCH may be replayed once after refresh |
| `idempotencyKey` | `null` | Sent as `Idempotency-Key` header when set |

`containsAccessToken: false` omits the Bearer header on the request; `skipTokenRefresh: true` keeps automatic refresh off when the server returns 401.

### POST retry policy (RFC 9110)

GET, PUT, and DELETE are retried once after a successful refresh. POST and PATCH are **not** retried unless you pass `allowRetryOn401: true`.

### Optional form-encoded refresh

```dart
NetKitManager(
  baseUrl: url,
  refreshTokenPath: '/oauth/token',
  refreshTokenContentType: RefreshTokenContentType.formUrlEncoded,
);
```

### Not an HTTP cache (RFC 9111)

Net-Kit does not implement HTTP caching (ETag, Cache-Control, etc.).

## testMode renamed to devMode: v5.4.0

### Why was it renamed?

`testMode` sounded like a unit-test flag, but it controls development behavior: using `devBaseUrl`, enabling logging, and similar dev-only features. `devMode` better matches that intent.

### How to migrate

- Before (deprecated)

```dart
NetKitManager(
  baseUrl: url,
  devBaseUrl: devUrl,
  testMode: kDebugMode,
);
```

- After (recommended)

```dart
NetKitManager(
  baseUrl: url,
  devBaseUrl: devUrl,
  devMode: kDebugMode,
);
```

`testMode` still works in this release but is deprecated and will be removed in a future major version.

If you read the flag from `NetKitParams`, use `parameters.devMode` instead of `parameters.testMode`.

## authenticate Method Deprecation: v3.6.0

### Why is `authenticate` Deprecated?

- The `authenticate` method assumes tokens are sent via **headers**, which can be logged in certain
  systems.
- It is more secure to **receive tokens in the response body** instead.
- The **requestModel** method gives developers more control over token parsing and storage.

### How to Migrate

- Before (Deprecated) ⛔

```dart
Future<(AuthResultModel, AuthTokenModel)> signIn({
  required SignInParams signInParams,
}) async {
  return _network.authenticate<AuthResultModel>(
    path: '/auth/sign-in',
    method: RequestMethod.post,
    model: AuthResultModel(),
    body: signInParams.toJson(),
  );
}
```

- After (Recommended) ✅

```dart
/// The result returns both the user model and the auth tokens
/// But it may differ based on your implementation
Future<(AuthResultModel, AuthTokenModel)> signIn({
  required SignInParams signInParams,
}) async {
  final authResult = await _network.requestModel<AuthResultModel>(
    path: '/auth/sign-in',
    method: RequestMethod.post,
    model: AuthResultModel(),
    body: signInParams.toJson(),
  );

  // Map token fields from your login model (adjust field names as needed)
  final authToken = AuthTokenModel(
    accessToken: authResult.accessToken,
    refreshToken: authResult.refreshToken,
  );

  _network
    ..setAccessToken(authToken.accessToken)
    ..setRefreshToken(authToken.refreshToken);

  return (authResult, authToken);
}
```

## Migration for Version 5.0.0

The v5.0.0 release of NetKit introduces several improvements and breaking changes, especially
related to token handling and RefreshTokenParams, to align
with [RFC 6749 §6](https://datatracker.ietf.org/doc/html/rfc6749#section-6). Below is a detailed
migration guide to help you upgrade smoothly.

### 🔁 1. **Breaking Change**: Refresh token is now sent in the body (not headers)

To comply with [RFC 6749 §6](https://datatracker.ietf.org/doc/html/rfc6749#section-6), the refresh
token is now included only in the request body, not headers. There is no need an action, as this is
handled under the hood.

### 🛡️ 2. Removed refreshTokenHeaderKey

The `refreshTokenHeaderKey` parameter has been removed entirely.

You no longer need to set the refresh token in headers manually.