![h)](https://github.com/user-attachments/assets/d8115ef2-4783-4d2d-88de-df57df40112f)

![Version](https://img.shields.io/pub/v/net_kit)
![License](https://img.shields.io/badge/license-MIT-green)
![Contributions welcome](https://img.shields.io/badge/contributions-welcome-orange)
![GitHub Sponsors](https://img.shields.io/badge/sponsors-welcome-yellow)

## **Contents**

<details>

<summary>🔽 Click to expand</summary>

<!-- TOC -->
  * [**Contents**](#contents)
  * [**Features**](#features)
  * [**Getting started**](#getting-started)
    * [**Initialize**](#initialize)
    * [**Extend the model**](#extend-the-model)
    * [**Custom Void Models in Uploading**](#custom-void-models-in-uploading)
  * [**Sending requests**](#sending-requests)
    * [**Available Request Methods**](#available-request-methods)
    * [**Request Examples**](#request-examples)
    * [**Why DataKey is Used**](#why-datakey-is-used)
    * [**DataKey Configuration**](#datakey-configuration)
    * [**Session invalidation**](#session-invalidation)
    * [**Advanced Examples**](#advanced-examples)
    * [**Setting Tokens**](#setting-tokens)
    * [**User Logout**](#user-logout)
  * [**Token Management**](#token-management)
    * [**Quick Token Setup**](#quick-token-setup)
    * [**Comprehensive Token Management**](#comprehensive-token-management)
    * [**Auth policy per request**](#auth-policy-per-request)
  * [**Logger Integration**](#logger-integration)
  * [**Architecture**](#architecture)
  * [**Raw HTTP transport**](#raw-http-transport)
    * [**Security model**](#security-model)
    * [**Methods, cancellation, and progress**](#methods-cancellation-and-progress)
    * [**Large file uploads**](#large-file-uploads)
    * [**Streaming responses**](#streaming-responses)
    * [**Origin and redirect policy**](#origin-and-redirect-policy)
    * [**Interceptors**](#interceptors)
* [Migration Guidance](#migration-guidance)
  * [**Feature Status**](#feature-status)
  * [**Contributing**](#contributing)
  * [**License**](#license)
<!-- TOC -->

</details>  

## **Features**

- 🧩 Transport-neutral public API: no HTTP-library types leak out of `package:net_kit/net_kit.dart`
- 🔄 Single-flight token refresh (one refresh for concurrent 401s) with replayable retries
- 🔑 `AuthPolicy` per request: `inherit`, `none` (public endpoints), `required`
- 🔒 RFC 9110-safe POST retry policy (`allowRetryOn401` opt-in)
- 🛡 API origin enforcement: credentials never leave `baseUrl`'s origin, not even on redirects
- ⚙️ `onBeforeRefreshRequest` to mutate refresh payload
- 🛠 Parsing responses into models or lists using `INetKitModel`
- 🧪 Configurable base URLs for development and production
- 🌐 Internationalization support for error messages
- 📦 Streaming multipart and file uploads that survive a token refresh
- 📋 Extensible logger integration with secret redaction
- 📡 `NetKitTransport` / `RawHttpClient` for absolute URLs, streamed bodies, and streamed responses

<!-- ## **Sponsors**

A big thanks to our awesome sponsors for keeping this project going!️ Want to help out? Consider
becoming a [sponsor](https://github.com/sponsors/behzodfaiziev/)!

<table style="background-color: white; border: 1px solid black">
    <tbody>
        <tr>
            <td style="border: 1px solid black">
                <a href="https://westudio.dev"><img src="https://github.com/user-attachments/assets/a7ce889d-340f-4c84-8cb1-6a94c31bacc5" width="225" alt="WESTUDIO"/></a>
            </td>
            <td style="border: 1px solid black">
                <a href="https://vremica.com"><img src="https://github.com/user-attachments/assets/25942faf-45dc-44cf-8422-2d2eb2711ac0" width="225" alt="VREMICA"/></a>
            </td>
            <td style="border: 1px solid black">
                <a href="https://jurnalle.com"><img src="https://github.com/user-attachments/assets/2de36aa9-2c4e-4669-b3db-b6565846e4c8" width="225" alt="JURNALLE"/></a>
            </td>
</table> -->

## **Getting started**

### **Initialize**

Initialize the NetKitManager with the parameters:

```dart
import 'package:net_kit/net_kit.dart';

final netKitManager = NetKitManager(
  baseUrl: 'https://api.<URL>.com',
  devBaseUrl: 'https://dev.<URL>.com',
  // ... other parameters
);
```

### **Extend the model**

Requests such as: `requestModel` and`requestList` require the model to
extend `INetKitModel` in order to be used with the NetKitManager. By extending, `INetKitModel`
`fromJson` and `toJson` methods will be needed to be implemented, so the model can be serialized and
deserialized.

```dart
class TodoModel extends INetKitModel {}
```

### **Custom Void Models in Uploading**

**⚠️ Custom Void Models:**
If you want to handle endpoints that return no data (i.e., void/empty responses) using your own
model, your model must implement VoidModel from this package.

Example:

```dart
class AppVoidModel implements INetKitModel, VoidModel {
  @override
  Map<String, dynamic> toJson() => {};

  @override
  AppVoidModel fromJson(Map<String, dynamic> json) => AppVoidModel();
}
```

Without implementing VoidModel, void requests will not be recognized correctly and may throw
exceptions.

## **Sending requests**

NetKitManager provides several methods for making HTTP requests. Each method is designed for specific use cases and response types.

### **Available Request Methods**

| Method | Description | Use Case |
|--------|-------------|----------|
| `requestModel` | Request a single model | Get a single resource |
| `requestList` | Request a list of models | Get multiple resources |
| `requestVoid` | Send a request without expecting data | Delete, update operations |
| `requestModelMeta` | Request a model with metadata | Get a resource with additional info |
| `requestListMeta` | Request a list with metadata | Get paginated data with metadata |
| `uploadMultipartData` | Upload a single file part (`NetKitMultipartFile`) | File uploads |
| `uploadFormData` | Upload `NetKitFormData` (fields + file parts) | Form submissions with files |
| `uploadRawData` | Upload raw bytes as request body | Binary/raw file uploads (web-safe) |
| `uploadFile` | Stream a file from disk as the raw request body | Large binary uploads from a path (IO only); see [Large file uploads](#large-file-uploads) |

### **Request Examples**

- **📋 [Request a Single Model →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#service-layer-pattern)**
- **📋 [Request a List of Models →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#service-layer-pattern)**
- **📋 [Send a Void Request →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#service-layer-pattern)**
- **📋 [Request Model with Metadata →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#service-layer-pattern)**
- **📋 [Request List with Metadata (Pagination) →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#pagination)**
- **📋 [Upload Multipart Data (Single File) →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#file-uploads)**
- **📋 [Upload Form Data →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#file-uploads)**
- **📋 [Upload Raw Data (Direct Binary) →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#file-uploads)**

### **Why DataKey is Used**

Many APIs return responses in a wrapped format where the actual data is nested under a specific key. For example:

```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com"
  },
  "message": "User retrieved successfully"
}
```

Without DataKey configuration, you would need to manually extract the data from the `data` field in every response. NetKit's DataKey feature automatically handles this extraction, making your code cleaner and more maintainable.

### **DataKey Configuration**

The `useDataKey` parameter (default: `true`) allows you to control whether to use the configured `dataKey` wrapper for individual requests. This is useful when you have different API endpoints that return data in different formats.

- When `useDataKey: true` (default): Uses the configured `dataKey` to extract data from the response
- When `useDataKey: false`: Uses `response.data` directly, ignoring the `dataKey` configuration
- **Note:** This parameter has no effect if `dataKey` is not set in the NetKitManager configuration

Available on all request methods: `requestModel`, `requestModelMeta`, `requestList`, `requestListMeta`, `uploadMultipartData`, `uploadFormData`, `uploadRawData`, and `uploadFile`.

### **Auth policy per request**

Every request method takes `authPolicy`:

| `AuthPolicy` | Access token | On `401` |
|--------------|--------------|----------|
| `inherit` (default) | Sent when one is stored | Refresh once, retry (GET/PUT/DELETE; POST/PATCH with `allowRetryOn401`) |
| `none` | Never sent | Returned to the caller, no refresh |
| `required` | Mandatory; fails before sending when missing | Refresh once, retry |

```dart
await netKitManager.requestModel<SessionModel>(
  path: '/auth/login',
  method: RequestMethod.post,
  model: const SessionModel(),
  body: credentials,
  authPolicy: AuthPolicy.none,
);
```

Per-request `headers` override the stored headers, `timeout` (`NetKitTimeout`) overrides the
manager-wide timeouts, and `cancellationToken` (`NetKitCancellationToken`) cancels the request;
one token may be shared by several requests.

### **Session invalidation**

Only one event ends a session: **the refresh endpoint answering HTTP 401.** NetKit then clears the
stored tokens, calls `onSessionInvalidated` once, and fails the waiting requests with
`ApiFailureType.sessionInvalidated`. Sign the user out there.

| Event | Session |
|-------|---------|
| An ordinary request returns 401 | Kept; one shared refresh and one retry |
| Refresh endpoint returns 401 | **Ended**: tokens cleared, `onSessionInvalidated` called once |
| Refresh fails offline, on DNS/TLS, by timeout, with `400`/`403`/`429`/`5xx`, or with a malformed or token-less response | Kept; the caller gets the real cause (`fromRefresh == true`) and the next 401 refreshes again |

```dart
final netKitManager = NetKitManager(
  baseUrl: 'https://api.<URL>.com',
  refreshTokenPath: '/auth/refresh',
  onSessionInvalidated: (exception) => authController.signOut(),
);
```

A network failure is never a sign-out signal. See
[TOKEN_MANAGEMENT.md](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/TOKEN_MANAGEMENT.md#when-the-session-ends-and-when-it-does-not)
for the complete rules.

### **Advanced Examples**

For more detailed examples including pagination, error handling, and real-world use cases, see [EXAMPLES.md](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md).


### **Setting Tokens**

The **NetKitManager** allows you to set and manage access and refresh tokens, which are essential
for
authenticated API requests. Below are the methods provided to set, update, and remove tokens.

**Setting Access and Refresh Tokens**

To set the access and refresh tokens, use the `setAccessToken` and `setRefreshToken` methods. The
`accessToken` token will be added to the headers of every request made by the NetKitManager.
Note: these should be set on every app launch or when the user logs in.

```dart
/// Your method to set the tokens
void setTokens(String accessToken, String refreshToken) {
  netKitManager.setAccessToken(accessToken);
  netKitManager.setRefreshToken(refreshToken);
}
```

### **User Logout**

When a user logs out, you should remove the access and refresh tokens using the `removeAccessToken`
and `removeRefreshToken` methods.

**Example:**

```dart
/// Method to log out the user
void logoutUser() {
  netKitManager.removeAccessToken();
  netKitManager.removeRefreshToken();
}
```

## **Token Management**

NetKitManager provides comprehensive token management including automatic refresh, secure storage, and RFC-compliant authentication flows.

### **Quick Token Setup**

```dart
final netKitManager = NetKitManager(
  baseUrl: 'https://api.example.com',
  refreshTokenPath: '/auth/refresh-token',
  onTokenRefreshed: (authToken) async {
    await secureStorage.saveTokens(
      accessToken: authToken.accessToken,
      refreshToken: authToken.refreshToken,
    );
  },
);
```

### **Comprehensive Token Management**

For detailed token management documentation including:
- **RFC Compliance** (OAuth 2.0, Bearer Token, HTTP Authentication)
- **Token Refresh Configuration** with advanced options
- **Secure Token Storage** best practices
- **Error Handling** for token operations
- **Security Considerations** and best practices

📋 **[View Complete Token Management Guide →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/TOKEN_MANAGEMENT.md)**

## **Logger Integration**

The `NetKitManager` uses a logger internally, for example, during the refresh token stages. To add
custom logging, you need to create a class that implements the `INetKitLogger` interface. Below is
an example of how to create a `NetworkLogger` class:

You can find the full example
of
`NetworkLogger` [here](https://github.com/behzodfaiziev/net-kit/blob/main/flutter_integration_test/lib/core/network/logger/network_logger.dart).

```dart

final netKitManager = NetKitManager(
  baseUrl: 'https://api.<URL>.com',
  devMode: true,
  loggerEnabled: true,
  logger: NetworkLogger(),
  // ... other parameters
);
```

**Note:** `loggerEnabled` and `logInterceptorEnabled` only take effect when `devMode` is `true`.
Set `devMode` to `kDebugMode` (or similar) in development and keep it `false` in production.

**Sensitive headers are redacted from HTTP logs.** When `logInterceptorEnabled` is `true`, Net-Kit
registers `RedactingLogInterceptor`. It prints the request URL, method, status code, and headers,
but the values of `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie`, `X-Api-Key`,
`Api-Key`, `X-Auth-Token`, `X-Refresh-Token`, `X-CSRF-Token`, `X-XSRF-Token`, and your
`accessTokenHeaderKey` are replaced with `[REDACTED]`. Bodies are **not** printed unless you opt in
with `logResponseBodies: true`. Add your own header names with `sensitiveHeaders`:

```dart
final netKitManager = NetKitManager(
  baseUrl: 'https://api.<URL>.com',
  devMode: kDebugMode,
  logInterceptorEnabled: true,
  sensitiveHeaders: const ['X-Tenant-Secret'],
);
```

What redaction does and does not cover:

- Header values in the sensitive set are redacted; other headers are printed as-is.
- URLs are logged with the values of credential-like query parameters replaced by `[REDACTED]`:
  `token`, `access_token`, `refresh_token`, `id_token`, `api_key`, `apikey`, `key`, `signature`,
  `sig`, `X-Goog-Signature`, `X-Goog-Credential`, `X-Amz-Signature`, `X-Amz-Credential`,
  `X-Amz-Security-Token`, `code`, `secret`, `client_secret`, `password`, and your
  `accessTokenBodyKey` / `refreshTokenBodyKey`. Add names with `sensitiveQueryParameters`.
  User-info (`user:password@`) is redacted too. Other parameters are logged as-is, so prefer
  headers for secrets that are not on this list.
- Request and response bodies are not logged by default. `logResponseBodies: true` prints them
  (through the development log interceptor and as parsed data in the injected `logger`'s debug
  messages). To log bodies with masking, register your own
  `RedactingLogInterceptor(logBodies: true, bodySanitizer: mask)` in `interceptors`.
- `loggerEnabled` and `logInterceptorEnabled` are ignored unless `devMode` is true.

## **Architecture**

```
Application
  ├─ NetKitManager            API client: base URL, models, dataKey, AuthPolicy,
  │    └─ NetKitTransport     token refresh, origin + redirect policy, interceptors
  └─ RawHttpClient            = NetKitTransport used directly: absolute URLs,
       └─ NetKitTransport     streamed bodies and responses, no auth assumptions

Transport adapters: DioNetKitTransport (default; `package:net_kit/net_kit_dio.dart`)
```

`package:net_kit/net_kit.dart` exports only net_kit-owned types. `NetKitManager` *has* a
transport; it is not an HTTP client itself. The default transport is Dio, but it is an adapter:
pass any `NetKitTransport` to the constructor, and import `package:net_kit/net_kit_dio.dart` only
when you need the Dio adapter or Dio types explicitly (for example to inject an `HttpClientAdapter`
for a proxy or certificate pinning).

```dart
import 'package:net_kit/net_kit.dart';
import 'package:net_kit/net_kit_dio.dart';

final manager = NetKitManager(
  baseUrl: 'https://api.<URL>.com',
  transport: DioNetKitTransport(httpClientAdapter: myAdapter), // optional
  timeout: const NetKitTimeout(connect: Duration(seconds: 10)),
  headers: {'Accept-Language': 'en'},
);
```

## **Raw HTTP transport**

`NetKitManager` is the API/model-oriented HTTP client: JSON envelopes, `INetKitModel`,
`dataKey`, authentication, and token refresh.

`RawHttpClient` is the same `NetKitTransport` contract used directly. It does not attach
authorization, does not refresh tokens, does not retry, does not follow redirects, and does not
treat non-2xx statuses as errors. Use it for header-driven protocols on absolute URLs (for example
a resumable upload session on a signed storage URL) and interpret statuses such as 308, 404, or 410
in your own protocol layer.

The transport owned by a manager carries none of the manager's state, so it doubles as the raw
client; or construct one explicitly from the Dio entrypoint.

```dart
final RawHttpClient client = manager.transport;
// or: import 'package:net_kit/net_kit_dio.dart'; final RawHttpClient client = DioNetKitTransport();

final file = File(filePath);
final response = await client.send(
  RawHttpRequest(
    uri: Uri.parse(uploadUrl),
    method: RawHttpMethod.put,
    headers: {'Content-Type': 'application/octet-stream'},
    body: FileRawHttpBody(file.path),
  ),
);

print(response.statusCode);
```

### **Security model**

The transport is deliberately dumb so that it is safe to point at any host:

- It sends exactly the headers you pass plus `Content-Length` for streamed and byte bodies. No
  `Authorization`, no implied `Content-Type`.
- Every HTTP status, including `3xx`, `401`, `403`, `404`, `409`, `429`, `500`, and `503`, is
  returned as a `RawHttpResponse`. It never refreshes tokens and never retries.
- Only transport failures throw `RawHttpException`, classified as `timeout`, `connection` (DNS,
  socket), `tls` (certificate), `cancellation`, `invalidResponse`, or `unknown`.
- The URL is sent byte for byte, so percent-encoded signed query strings are preserved.
- Redirects are not followed unless `RawHttpRequest(followRedirects: true)`; the underlying HTTP
  client may forward all headers when it follows redirects, so keep the default for signed URLs.

### **Methods, cancellation, and progress**

`RawHttpMethod` covers `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, and `OPTIONS`.

`NetKitCancellationToken` (the same type `NetKitManager` uses; `RawHttpCancellationToken` is an
alias) can be shared by several in-flight requests. `cancel()` is idempotent, cancels every bound
request, and a cancelled token passed to a new request cancels it before anything is sent.
Requests release their binding when they finish, so nothing leaks through a long-lived token.
Progress callbacks (`NetKitProgressCallback`) report `(count, total)` for uploads and downloads.

```dart
final token = NetKitCancellationToken();

final upload = client.send(
  RawHttpRequest(
    uri: Uri.parse(uploadUrl),
    method: RawHttpMethod.put,
    headers: {'Content-Type': 'application/octet-stream'},
    body: FileRawHttpBody(filePath),
    cancellationToken: token,
    timeout: const NetKitTimeout(send: Duration(minutes: 5)),
    onSendProgress: (sent, total) => print('$sent / $total'),
  ),
);

// Later, e.g. from a cancel button:
token.cancel();
```

`response.header(name)` returns the first value; `response.headerValues(name)` returns every
value (for example `Set-Cookie`). `contentLength` and `isSuccessful` are available on both
buffered and streamed responses.

### **Large file uploads**

Request bodies are either replayable or single-shot:

| Body | Replayable | Memory |
|------|------------|--------|
| `BytesRawHttpBody`, `StringRawHttpBody` | yes | in memory |
| `FileRawHttpBody(path)` | yes, reopened per attempt | streamed from disk |
| `ReplayableRawHttpBody(open: () => stream, contentLength: n)` | yes, `open()` per attempt | streamed |
| `NetKitFormData` with `NetKitMultipartFile` parts | yes | streamed parts |
| `StreamRawHttpBody(stream: s, contentLength: n)` | no | streamed once |

`NetKitManager.uploadFile` streams the file with `File.openRead()` and sends `Content-Length`
from `File.length()`. If the request is retried after a token refresh, the file is reopened and
sent again in full. `uploadFormData` / `uploadMultipartData` behave the same for every file part
created with `NetKitMultipartFile.fromPath` or `fromStream`. Nothing is read into memory as a
whole, whatever the file size.

### **Streaming responses**

`send` buffers the whole response body (`bodyBytes`), which is right for API payloads. For large
downloads use `sendStreamed`: the status and headers arrive first and the body is a
back-pressured `Stream<List<int>>` that honours the cancellation token.

```dart
final response = await client.sendStreamed(
  RawHttpRequest(uri: Uri.parse(downloadUrl), method: RawHttpMethod.get),
);
if (response.isSuccessful) {
  await response.body.pipe(File(target).openWrite());
}
```

Consume the body to completion or cancel it so the connection is released.

### **Origin and redirect policy**

`NetKitManager` treats the origin of `baseUrl` (or `devBaseUrl` in dev mode) as a trust boundary:

- A `path` that is an absolute URL on another origin fails with
  `ApiException(type: invalidRequest)` carrying `crossOriginRequestBlockedError` before anything
  is sent. Opt in with `allowCrossOriginRequests: true`; such requests are then sent **without**
  the stored headers and access token (per-request headers are kept).
- The manager follows up to five redirects itself. Same-origin redirects keep headers; `303` and
  `301`/`302` after a `POST` become body-less `GET`; `307`/`308` keep the method and a replayable
  body. A redirect to another origin is blocked by default and, when allowed, is followed without
  stored or sensitive headers.
- `AuthPolicy.required` cannot target another origin.
- The refresh request never leaves the API origin, regardless of `allowCrossOriginRequests`,
  `onBeforeRefreshRequest`, interceptors, or redirects.
- If an interceptor rewrites a request to another origin, the same rules apply: blocked by
  default, and sent without stored or sensitive headers when allowed.

Signed storage URLs belong on the transport (`RawHttpClient`), which has no credentials to leak.

**Web builds.** Browsers follow redirects inside `XMLHttpRequest` and do not let the application
see or stop them, so the redirect rules above cannot be applied hop by hop on the web. What still
holds there: browsers that implement the current Fetch standard drop `Authorization` when a
redirect crosses origins; a refresh
response that came from a redirect is rejected rather than trusted; and requests that the manager
blocks by origin are blocked before the browser is involved. What does not hold: custom headers
(for example `X-Api-Key`) and a `307`/`308` request body can be forwarded by the browser to a
cross-origin redirect target if that target accepts the CORS preflight. Only your API server can
issue such a redirect, so avoid open redirects on authenticated and refresh endpoints.

### **Interceptors**

`NetKitInterceptor` is the application hook. It sees the final `RawHttpRequest` (absolute URL,
merged headers after the auth policy) before each transport attempt, the raw response, and the
`ApiException` a request is about to throw.

```dart
class TraceInterceptor extends NetKitInterceptor {
  const TraceInterceptor();

  @override
  RawHttpRequest onRequest(RawHttpRequest request) {
    return request.copyWith(headers: {...request.headers, 'X-Trace': newTraceId()});
  }

  @override
  ApiException onError(RawHttpRequest? request, ApiException error) {
    metrics.count(error.type);
    return error;
  }
}

final manager = NetKitManager(baseUrl: url, interceptors: const [TraceInterceptor()]);
```

Auth injection, token refresh, origin checks, and error mapping are done by `NetKitManager`;
interceptors observe or adjust their result.

# Migration Guidance

➡️ For detailed upgrade steps and breaking changes, see the full [Migration Guide](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/MIGRATION.md).

## **Feature Status**

| *Feature*                                                   | *Status* |
|:------------------------------------------------------------|:--------:|
| Internationalization support for error messages             |    ✅     |
| No internet connection handling                             |    ✅     |
| Basic examples and documentation                            |    ✅     |
| Comprehensive examples and use cases                        |    ✅     |
| MultiPartFile upload support                                |    ✅     |
| FormData upload support                                     |    ✅     |
| Refresh Token implementation (RFC 6749/6750 compliant)     |    ✅     |
| Customizable logging with log levels                        |    ✅     |
| Automatic token-refresh for 401 (single-flight)              |    ✅     |
| POST/PATCH blocked from auto-retry unless opted in           |    ✅     |
| `AuthPolicy` / `allowRetryOn401` / `idempotencyKey`          |    ✅     |
| Comprehensive test coverage                                 |    ✅     |
| Authentication and token management                         |    ✅     |
| DataKey configuration with per-request override            |    ✅     |
| Pagination support with metadata                            |    ✅     |
| Service layer pattern examples                              |    ✅     |
| Repository pattern examples                                 |    ✅     |
| Error handling strategies                                   |    ✅     |
| File upload with wrapper patterns                           |    ✅     |
| Token management documentation                              |    ✅     |
| Transport abstraction (`NetKitTransport`, Dio adapter)       |    ✅     |
| Isolated raw HTTP transport (`RawHttpClient`)               |    ✅     |
| Streamed request bodies and streamed responses              |    ✅     |
| Replayable file uploads across token refresh                |    ✅     |
| API-origin enforcement and safe redirects                   |    ✅     |

## **Contributing**

Contributions are welcome! Please open an [issue](https://github.com/behzodfaiziev/net-kit/issues)
or submit a [pull request](https://github.com/behzodfaiziev/net-kit/pulls).

Run the deterministic test suite with `dart test --exclude-tags live`. Tests tagged `live` call
public third-party APIs and can be run separately with `dart test --tags live`.

## **License**

This project is licensed under the MIT License.
