# Netkit

Secure, flexible networking for Dart and Flutter.

Netkit (`net_kit` on pub.dev) gives you typed API requests, explicit per-request authentication,
coordinated token refresh with predictable session invalidation, streaming and replayable uploads,
signed and external URLs, cancellation and progress, and raw HTTP when you need the protocol
itself.



[![pub package](https://img.shields.io/pub/v/net_kit.svg)](https://pub.dev/packages/net_kit)
[![Build and Test](https://github.com/behzodfaiziev/net-kit/actions/workflows/test.yml/badge.svg)](https://github.com/behzodfaiziev/net-kit/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)


<img width="1672" height="941" alt="111" src="https://github.com/user-attachments/assets/da7b00ae-2cd9-4bf8-9b5d-9c246f5101cc" />

## Contents

- [Why Netkit?](#why-netkit)
- [Install](#install) and [Quick start](#quick-start)
- [Which API should I use?](#which-api-should-i-use)
- [Requests](#requests)
- [Authentication](#authentication)
  - [AuthPolicy](#authpolicy)
  - [Refresh and session invalidation](#refresh-and-session-invalidation)
- [Uploads and streaming](#uploads-and-streaming)
  - [Large file uploads](#large-file-uploads)
  - [Streaming responses](#streaming-responses)
  - [Cancellation and progress](#cancellation-and-progress)
- [Raw HTTP and signed URLs](#raw-http-and-signed-urls)
- [Security](#security) and [Logging](#logging)
- [Architecture](#architecture)
- [Netkit MCP](#netkit-mcp)
- [Migrating from 5.x](#migrating-from-5x)
- [Documentation](#documentation)

## Why Netkit?

- **Typed requests.** Responses are parsed into your models and lists, with optional envelope
  unwrapping and pagination metadata.
- **Explicit authentication.** Each request declares its `AuthPolicy` (`inherit`, `none`, or
  `required`) instead of relying on URL patterns or interceptor state.
- **Safe token refresh.** Concurrent `401` responses share a single refresh, then retry.
- **Predictable sessions.** A session ends only when the refresh endpoint itself answers HTTP
  `401`. Offline devices, timeouts, and server errors never sign the user out.
- **Streaming, replayable uploads.** Large files stream from disk and are reopened when a request
  is retried after a refresh, so they are never held in memory.
- **Signed and external URLs.** GCS/S3 signed uploads go through `RawHttpClient`, which carries no
  application credentials; stored tokens never leave your API origin by default.
- **Cancellation and progress** on every request, with one token shared across many.

## Install

```bash
dart pub add net_kit:^6.0.0-dev.1
```

In a Flutter app, use `flutter pub add net_kit:^6.0.0-dev.1`. This README describes the 6.0
pre-release; upgrading from 5.x is covered in [Migrating from 5.x](#migrating-from-5x).

## Quick start

Define a model by extending `INetKitModel`:

```dart
import 'package:net_kit/net_kit.dart';

class Todo extends INetKitModel {
  const Todo({this.id, this.title, this.completed = false});

  final int? id;
  final String? title;
  final bool completed;

  @override
  Todo fromJson(Map<String, dynamic> json) => Todo(
        id: json['id'] as int?,
        title: json['title'] as String?,
        completed: json['completed'] as bool? ?? false,
      );

  @override
  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'completed': completed};
}
```

Create one manager for your API and send typed requests:

```dart
final manager = NetKitManager(baseUrl: 'https://api.example.com');

Future<void> main() async {
  try {
    final todo = await manager.requestModel<Todo>(
      path: '/todos/1',
      method: RequestMethod.get,
      model: const Todo(),
    );
    print(todo.title);
  } on ApiException catch (e) {
    // e.type is an ApiFailureType: response, transport, timeout, cancelled,
    // auth, sessionInvalidated, decoding, invalidRequest, or unknown.
    print('${e.type} ${e.statusCode}: ${e.message}');
  }
}
```

Every `NetKitManager` request throws `ApiException` on failure; no transport-library exception
escapes it.

## Which API should I use?

| Need | Use |
| --- | --- |
| Your application's API | `NetKitManager` |
| A model, a list, or no response body | `requestModel`, `requestList`, `requestVoid` |
| Paginated data with metadata | `requestListMeta` |
| A public endpoint (login, registration) | `NetKitManager` with `AuthPolicy.none` |
| An endpoint that must be authenticated | `NetKitManager` with `AuthPolicy.required` |
| Multipart or form uploads | `uploadMultipartData`, `uploadFormData` |
| A large file to your API | `uploadFile` (streamed from disk) |
| Signed GCS/S3 or any external URL | `RawHttpClient` with `FileRawHttpBody` |
| A large download | `RawHttpClient.sendStreamed` |
| A custom Dio adapter (proxy, certificate pinning) | `DioNetKitTransport` from `net_kit_dio.dart` |

## Requests

| Method | Returns |
| --- | --- |
| `requestModel<R>` | `R` parsed from a JSON object |
| `requestList<R>` | `List<R>` parsed from a JSON array |
| `requestVoid` | nothing; any 2xx (including `204`) succeeds |
| `requestModelMeta<R, M>` | `ApiMetaResponse<R, M>`: the model plus metadata |
| `requestListMeta<R, M>` | `ApiMetaResponse<List<R>, M>`: for pagination |
| `uploadMultipartData<R>` | `R`; one `NetKitMultipartFile` as `multipart/form-data` |
| `uploadFormData<R>` | `R`; `NetKitFormData` with fields and files |
| `uploadRawData<R>` | `R`; raw bytes as the body (works on web) |
| `uploadFile<R>` | `R`; a file streamed from disk as the body (not on web) |

All methods accept `headers`, `queryParameters`, `timeout` (`NetKitTimeout`),
`cancellationToken`, progress callbacks, and `authPolicy`. A `body` map is sent as JSON unless a
`Content-Type` header says otherwise. Upload endpoints that return no body can use `VoidModel` as
`R`; a custom empty model must `implements VoidModel` to be recognized.

See [EXAMPLES.md](EXAMPLES.md) for service and repository layers, pagination, uploads, and
error handling.

### Response envelopes

If your API wraps payloads, set `dataKey` once and Netkit unwraps every response:

```json
{ "success": true, "data": { "id": 1, "title": "Write docs" } }
```

```dart
final manager = NetKitManager(baseUrl: 'https://api.example.com', dataKey: 'data');
```

For an endpoint that returns an unwrapped payload, pass `useDataKey: false` on that request.
Meta requests split the envelope: the payload under `metadataDataKey` (default `'data'`) becomes
the model and the remaining fields become the metadata model.

## Authentication

### AuthPolicy

| `AuthPolicy` | Access token | No token stored | On `401` |
| --- | --- | --- | --- |
| `inherit` (default) | Sent when stored | Request is sent without it | One shared refresh, then retry |
| `none` | Never sent | Request is sent | Returned to the caller; no refresh |
| `required` | Always sent | Fails before sending (`ApiFailureType.auth`) | One shared refresh, then retry |

After a refresh, `GET`, `PUT`, and `DELETE` are retried automatically. `POST` and `PATCH` are
retried only with `allowRetryOn401: true`; pair it with `idempotencyKey` when the server supports
it.

```dart
final session = await manager.requestModel<Session>(
  path: '/auth/login',
  method: RequestMethod.post,
  model: const Session(),
  body: {'email': email, 'password': password},
  authPolicy: AuthPolicy.none,
);
manager
  ..setAccessToken(session.accessToken)
  ..setRefreshToken(session.refreshToken);
```

Netkit holds the tokens in memory and attaches, refreshes, and clears them. It does not persist
them. Store tokens with your application's secure-storage solution, restore them into
`NetKitManager` when the app starts, and save refreshed tokens from `onTokenRefreshed`. Call
`removeAccessToken()` and `removeRefreshToken()` when the user signs out.

### Refresh and session invalidation

Set `refreshTokenPath` to enable refresh. Netkit posts the refresh token to that path, stores
the new tokens, and retries the waiting requests.

> **Only one event ends a session: the refresh endpoint answering HTTP `401`.**

| Event | Result |
| --- | --- |
| An ordinary request returns `401` | Session kept; one shared refresh, then retry |
| The refresh endpoint returns `401` | Session ended: tokens cleared, `onSessionInvalidated` called once |
| Refresh fails offline, on DNS or TLS, by timeout or cancellation, with `429`, `5xx`, or another `4xx`, or returns a malformed or token-less response | Session kept; the caller gets the real cause with `fromRefresh == true`, and the next `401` refreshes again |

```dart
final manager = NetKitManager(
  baseUrl: 'https://api.example.com',
  refreshTokenPath: '/auth/refresh',
  onTokenRefreshed: (tokens) => tokenStore.save(tokens),
  onSessionInvalidated: (exception) => authController.signOut(),
);
```

Sign the user out in `onSessionInvalidated`, not when a request fails. A network failure is
never a sign-out signal. [TOKEN_MANAGEMENT.md](TOKEN_MANAGEMENT.md) covers the refresh request
format, its configuration, and the complete rules.

## Uploads and streaming

### Request bodies

| Body | Replayable | Memory |
| --- | --- | --- |
| `BytesRawHttpBody`, `StringRawHttpBody` | Yes | Buffered |
| `FileRawHttpBody(path)` | Yes, reopened per attempt | Streamed from disk |
| `ReplayableRawHttpBody(open: ..., contentLength: n)` | Yes, `open()` per attempt | Streamed |
| `NetKitFormData` with `NetKitMultipartFile` parts | Yes | Streamed parts |
| `StreamRawHttpBody(stream: ..., contentLength: n)` | No, single-shot | Streamed once |

A replayable body can be sent again after a token refresh or a `307`/`308` redirect. A
single-shot body cannot; such a request fails with `invalidRequest` instead of sending a partial
payload.

### Large file uploads

`uploadFile` streams the file and sends its `Content-Length`; nothing is read into memory as a
whole. After a refresh the file is reopened and sent again in full. Multipart parts created with
`NetKitMultipartFile.fromPath` behave the same way.

```dart
await manager.uploadFile<VoidModel>(
  path: '/videos/42/content',
  model: VoidModel(),
  filePath: filePath,
  method: RequestMethod.put,
  contentType: 'video/mp4',
  onSendProgress: (sent, total) => print('$sent / $total'),
);
```

### Streaming responses

`send` buffers the response body, which suits API payloads. For large downloads,
`sendStreamed` returns the status and headers first and the body as a back-pressured stream:

```dart
final RawHttpClient client = manager.transport;

final response = await client.sendStreamed(
  RawHttpRequest(uri: Uri.parse(downloadUrl), method: RawHttpMethod.get),
);
if (response.isSuccessful) {
  await response.body.pipe(File(targetPath).openWrite());
} else {
  await response.body.drain<void>();
}
```

Consume or cancel the body so the connection is released.

### Cancellation and progress

A `NetKitCancellationToken` cancels every request it is passed to, on both the manager and the
raw client. `cancel()` is idempotent, and a token cancelled in advance stops a request before it
is sent. `onSendProgress` and `onReceiveProgress` report `(count, total)`.

```dart
final token = NetKitCancellationToken();
final future = manager.requestList<Todo>(
  path: '/todos',
  method: RequestMethod.get,
  model: const Todo(),
  cancellationToken: token,
);
token.cancel(); // future fails with ApiFailureType.cancelled
```

## Raw HTTP and signed URLs

`NetKitManager` provides application API semantics: base URL, models, envelopes, auth, refresh.
`RawHttpClient` provides protocol-level HTTP on absolute URLs. It is the same `NetKitTransport`
the manager sends through, used directly, so there is one transport, one set of body types, and
one cancellation model.

`RawHttpClient` does **not**:

- attach the manager's headers or access token;
- refresh tokens or retry;
- follow redirects (unless `RawHttpRequest(followRedirects: true)`);
- treat any status as an error. `3xx`, `401`, `404`, and `5xx` are returned as responses.

It throws `RawHttpException` only for transport failures (`timeout`, `connection`, `tls`,
`cancellation`, `invalidResponse`, `unknown`). URLs are sent byte for byte, so signed query
strings stay intact.

```dart
final RawHttpClient client = manager.transport;

final response = await client.send(
  RawHttpRequest(
    uri: Uri.parse(signedUploadUrl),
    method: RawHttpMethod.put,
    headers: {'Content-Type': 'application/octet-stream'},
    body: FileRawHttpBody(filePath),
  ),
);
if (!response.isSuccessful) {
  // Interpret the status for your storage protocol, e.g. 308 for resumable uploads.
}
```

## Security

- **The API origin is a credential boundary.** An absolute `path` on another origin fails with
  `invalidRequest` before anything is sent. With `allowCrossOriginRequests: true` it is sent, but
  without the stored headers and access token.
- **`AuthPolicy.required` never leaves the API origin.**
- **Redirects are checked hop by hop.** The manager follows up to five redirects itself; a
  redirect to another origin is blocked by default and, when allowed, followed without stored or
  sensitive headers.
- **The refresh request is pinned to the API origin**, regardless of `allowCrossOriginRequests`,
  `onBeforeRefreshRequest`, interceptors, or redirects.
- **The raw client has no auth state**, so a signed URL can never receive your access token.
- **Development logs redact credentials** (see [Logging](#logging)).

**Web builds.** Browsers follow redirects inside `XMLHttpRequest`, so the redirect checks cannot
run hop by hop on the web. Browsers implementing the current Fetch standard drop `Authorization`
on cross-origin redirects, and a refresh response that arrived through a redirect is rejected.
Custom credential headers and `307`/`308` bodies can still be forwarded by the browser to a
cross-origin target that accepts the CORS preflight, so avoid open redirects on authenticated
endpoints.

## Logging

```dart
final manager = NetKitManager(
  baseUrl: 'https://api.example.com',
  devMode: kDebugMode, // package:flutter/foundation.dart
  logInterceptorEnabled: true,
  sensitiveHeaders: const ['X-Tenant-Secret'],
);
```

- Logging options take effect only when `devMode` is `true`. `devMode` also switches to
  `devBaseUrl` when one is set, so keep it `false` in production.
- The log interceptor prints method, URL, status, and headers. Values of `Authorization`,
  `Cookie`, `Set-Cookie`, common API-key and token headers, your `accessTokenHeaderKey`, and
  `sensitiveHeaders` are replaced with `[REDACTED]`. Credential-like query parameters (`token`,
  `api_key`, `signature`, `X-Amz-Signature`, ...) are redacted too; add names with
  `sensitiveQueryParameters`.
- Bodies are not logged unless `logResponseBodies: true`.
- Redaction works by name. A secret in a header or parameter it does not recognize is printed
  as-is, so register custom names.
- For internal events such as refresh stages, pass your own `INetKitLogger` with
  `loggerEnabled: true`.

## Architecture

```
Application
    │
    ├── NetKitManager ─────── base URL, models, envelopes, AuthPolicy,
    │       │                 refresh, origin and redirect policy, interceptors
    │       ▼
    │   NetKitTransport ◄──── RawHttpClient (the same contract, used directly
    │       │                 for absolute URLs; no auth, no retries)
    │       ▼
    └── DioNetKitTransport    default adapter
```

Netkit's public API is transport-neutral. `NetKitManager` *has* a transport rather than being an
HTTP client, and `package:net_kit/net_kit.dart` exports only Netkit-owned types, so application
code never depends on Dio. Dio is the default adapter, not the architecture.

| Import | Contains |
| --- | --- |
| `package:net_kit/net_kit.dart` | Everything above, as Netkit-owned types only |
| `package:net_kit/net_kit_dio.dart` | `DioNetKitTransport` and a re-export of `package:dio` |

### Using the Dio adapter

Most applications do not import `net_kit_dio.dart`. Import it to configure the Dio adapter, for
example a custom `HttpClientAdapter` for a proxy or certificate pinning, or to create a raw
client without a manager:

```dart
import 'package:net_kit/net_kit.dart';
import 'package:net_kit/net_kit_dio.dart';

final manager = NetKitManager(
  baseUrl: 'https://api.example.com',
  transport: DioNetKitTransport(httpClientAdapter: myAdapter),
);
```

Any `NetKitTransport` implementation can be passed as `transport`. A transport you inject is not
closed by `manager.dispose()`.

### Interceptors

`NetKitInterceptor` sees the final `RawHttpRequest` before each attempt, the raw response, and
any `ApiException` before it is thrown. Auth, refresh, and origin checks run in the manager;
interceptors observe or adjust their result, and the origin rules still apply to any URL an
interceptor rewrites.

```dart
class TraceInterceptor extends NetKitInterceptor {
  const TraceInterceptor();

  @override
  RawHttpRequest onRequest(RawHttpRequest request) =>
      request.copyWith(headers: {...request.headers, 'X-Trace': newTraceId()});
}
```

## Netkit MCP

[`flutter-net-kit-mcp`](https://www.npmjs.com/package/flutter-net-kit-mcp) is an optional,
read-only [Model Context Protocol](https://modelcontextprotocol.io) server for working with
Netkit in MCP-compatible editors and assistants. It can:

- answer questions from the Netkit API and documentation for a specific version;
- recommend request, auth, upload, and streaming patterns;
- review an authorized Dart/Flutter workspace for Netkit-specific auth, refresh, upload,
  streaming, and 5.x → 6.0 migration issues;
- suggest changes without modifying any file.

Knowledge-only mode, with no project access:

```bash
npx -y flutter-net-kit-mcp@next --no-workspace
```

It works with any standards-compliant MCP client. For example, in Claude Code:

```bash
claude mcp add net-kit -- npx -y flutter-net-kit-mcp@next
```

The server is a separate Node.js developer tool. Netkit does not depend on it, does not call
any AI service, and never sends your source code anywhere.

## Migrating from 5.x

6.0 is a major release. The main changes:

- `package:net_kit/net_kit.dart` no longer exposes Dio types; Dio lives in `net_kit_dio.dart`.
- `AuthPolicy` replaces `containsAccessToken` and `skipTokenRefresh`.
- `NetKitManager` composes a `NetKitTransport`; `RawHttpClient` is that contract used directly.
- `NetKitCancellationToken`, `NetKitProgressCallback`, and `NetKitTimeout` replace Dio's
  equivalents; uploads take `NetKitFormData` and `NetKitMultipartFile`.
- Uploads stream from disk and replay after a refresh.
- `onSessionInvalidated` replaces `onRefreshFailed`, with the session rules above.
- Cross-origin requests are blocked by default.

[MIGRATION.md](MIGRATION.md) has the full breaking-change ledger and before/after examples.

## Documentation

| Guide | Covers |
| --- | --- |
| [EXAMPLES.md](EXAMPLES.md) | Service and repository layers, pagination, uploads, error handling |
| [TOKEN_MANAGEMENT.md](TOKEN_MANAGEMENT.md) | Authentication, refresh configuration, session rules |
| [MIGRATION.md](MIGRATION.md) | Upgrading from 5.x to 6.0 and earlier versions |
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [API reference](https://pub.dev/documentation/net_kit/latest/) | Generated Dart API documentation |

## Contributing

Issues and pull requests are welcome on
[GitHub](https://github.com/behzodfaiziev/net-kit/issues). Run the deterministic test suite with
`dart test --exclude-tags live`; tests tagged `live` call public third-party APIs.

## License

MIT. See [LICENSE](LICENSE).
