# 6.0.0-dev.1

Pre-release of the 6.0 major version. The public API no longer exposes Dio; see
`MIGRATION.md` ("Migrating from 5.x to 6.0") for the full breaking-change ledger.

### Breaking Changes

- `package:net_kit/net_kit.dart` no longer exports `package:dio`. Every type in the main
  entrypoint is owned by net_kit. The Dio adapter and a Dio re-export live in the new
  `package:net_kit/net_kit_dio.dart`
- `NetKitManager` composes a `NetKitTransport` instead of being a Dio instance. Constructor
  changes: `httpClientAdapter` → `transport`, `baseOptions` → `headers` + `timeout`
  (`NetKitTimeout`), `interceptor` (Dio) → `interceptors` (`List<NetKitInterceptor>`);
  the deprecated `testMode` is removed; `INetKitManager.baseOptions` is removed and
  `INetKitManager.transport` is added
- Request methods take `headers`, `timeout`, `cancellationToken` (`NetKitCancellationToken`),
  `NetKitProgressCallback`s, and `authPolicy` instead of `options`, `cancelToken`,
  `ProgressCallback`, `containsAccessToken`, and `skipTokenRefresh`
- `AuthPolicy { inherit, none, required }` replaces the two auth booleans. `none` never attaches
  the access token and never refreshes; `required` fails before sending when no token is stored
- `allowCrossOriginRequests` now defaults to `false`. When enabled, requests and redirects to
  another origin are sent without the stored headers and access token
- `uploadFile` streams the file from disk (`File.openRead()`); it no longer reads the whole file
  into memory. Uploads take `NetKitFormData` / `NetKitMultipartFile` instead of Dio `FormData` /
  `MultipartFile`; `uploadMultipartData` gained `fieldName`; the `contentType` parameter of
  `uploadFormData` / `uploadMultipartData` is gone (the transport sets the multipart boundary)
- `ApiException` gained `type` (`ApiFailureType`: response, transport, timeout, cancelled, auth,
  decoding, invalidRequest, sessionInvalidated, unknown). `RequestExtraKeys` is removed;
  `RefreshTokenContentType` moved to its own file
- `onRefreshFailed` is removed. `onSessionInvalidated` is called once, and the stored tokens are
  cleared, only when the **refresh endpoint** answers HTTP `401`. Every other refresh failure
  (offline, DNS, TLS, timeout, cancellation, `429`, `5xx`, other `4xx`, malformed or token-less
  responses) keeps the tokens, reaches the caller with its own `ApiFailureType` and
  `ApiException.fromRefresh == true`, and is retried on the next `401`
- `removeAccessTokenBeforeRefresh` no longer deletes the stored access token; it only omits the
  header from the refresh request
- A `401` without a configured `refreshTokenPath` is now returned to the caller instead of
  failing with "Refresh token path is not set"
- Raw transport: `RawHttpClient` is an alias of `NetKitTransport`, `DioRawHttpClient` an alias of
  `DioNetKitTransport` (import `net_kit_dio.dart`). `RawHttpRequest` takes `timeout:
  NetKitTimeout` instead of three durations. `RawHttpResponse.body` → `bodyBytes`;
  `header(name)` returns the first value instead of comma-joining. `RawHttpFailureType` gained
  `tls` (certificate failures, previously `connection`) and `invalidResponse` (previously
  `unknown`)
- Redirects are no longer followed by the HTTP client. `NetKitManager` follows up to five
  redirects itself under the origin policy; the raw transport returns `3xx` unless
  `RawHttpRequest.followRedirects` is true

### Features

- `NetKitTransport`: the net_kit-owned transport contract (`send`, `sendStreamed`, `close`).
  `DioNetKitTransport` is the default implementation; any implementation can be injected
- `NetKitInterceptor`: application hooks (`onRequest`, `onResponse`, `onError`) over the final
  transport request, response, and `ApiException`
- Streamed responses: `NetKitTransport.sendStreamed` returns `RawHttpStreamedResponse` with the
  status and headers first and a back-pressured body stream; cancellation ends the stream
- Replayable request bodies: `ReplayableRawHttpBody` (fresh stream per attempt) and
  `FileRawHttpBody` (streams from disk). `NetKitManager` reopens them for the retry after a token
  refresh and for `307`/`308` redirects, so large uploads never buffer
- `NetKitFormData` / `NetKitMultipartFile` describe multipart bodies without Dio; file parts are
  stream factories, so multipart uploads stream and replay
- `NetKitTimeout` (connect, send, receive) for the manager, per request, and on raw requests
- Redirect policy: same-origin redirects keep headers; `303` and `301`/`302` after `POST` become
  `GET`; cross-origin redirects are blocked by default and never forward credentials
- `RawHttpResponse.contentLength`, `isSuccessful`, `bodyText`; `RawHttpRequest.copyWith`,
  `onReceiveProgress`, `followRedirects`; `RawHttpBody.isReplayable`
- `NetKitManager(logResponseBodies: ...)`: response bodies are kept out of the injected logger
  and the development log interceptor unless opted in. `RedactingLogInterceptor` is a
  `NetKitInterceptor` with `logBodies` and `bodySanitizer`
- New `NetKitErrorParams` messages: `missingAccessTokenError`, `timeoutError`,
  `requestCancelledError`, `transportError`, `tooManyRedirectsError`, `nonReplayableBodyError`,
  `sessionInvalidatedError`, `unverifiedRedirectError`
- `RawHttpResponse.redirected` / `RawHttpStreamedResponse.redirected` report redirects the HTTP
  client followed on its own (browsers always do)
- `NetKitManager(sensitiveQueryParameters: ...)` and
  `RedactingLogInterceptor(sensitiveQueryParameters: ...)`

### Security

- Refresh requests are pinned to the API origin: `allowCrossOriginRequests`,
  `onBeforeRefreshRequest`, interceptors, and redirects cannot send the refresh credential to
  another origin. On the web, a refresh response that came from a browser-followed redirect is
  rejected
- Origin rules are re-applied after interceptors run, so an interceptor cannot carry stored
  credentials to another origin
- Logged URLs redact credential-like query parameters (signed URL signatures, OAuth codes, API
  keys, tokens) and user-info
- A refresh result that arrives after the application stored new credentials is discarded instead
  of overwriting them, and a refresh `401` for superseded credentials does not end the new session
- Cancelling a request that waits for a refresh releases it immediately without cancelling the
  shared refresh

### Improvements

- Timeouts, cancellation, connection, and TLS failures are reported as typed `ApiException`s
  instead of a generic parse error
- `uploadMultipartData` sends a real multipart body (the file under `fieldName`) instead of the
  string form of the file object

# 5.5.0

### Features

- Added `RawHttpClient`, an isolated, transport-independent client for raw HTTP to absolute URLs
  (for example signed object-storage uploads). It sends only caller-owned headers, never attaches
  the `NetKitManager` access token, never refreshes tokens, never retries, and returns every HTTP
  status (including 401 and 5xx) as a `RawHttpResponse`; only transport failures throw
  `RawHttpException`
- `DioRawHttpClient` is the built-in implementation; application code should depend on
  `RawHttpClient` so the transport can change without caller changes
- `StreamRawHttpBody` streams request bodies (for example `File.openRead()`) without buffering them,
  with `Content-Length`, upload progress (`onSendProgress`), and timeouts
- `RawHttpCancellationToken` cancels raw requests without exposing Dio's `CancelToken`. One token may
  be shared by several in-flight requests; cancellation is idempotent, a cancelled token fails new
  requests before sending, and completed requests release their binding
- `RawHttpMethod` covers `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, and `OPTIONS`
- `RawHttpResponse.headerValues(name)` returns repeated header values unjoined (for example
  `Set-Cookie`); response header collections are unmodifiable
- Optional cross-origin protection: `NetKitManager(allowCrossOriginRequests: false)` rejects requests
  whose absolute URL has a different origin than `baseUrl` before anything is sent, so the access
  token cannot reach an unrelated host. Adds `NetKitErrorParams.crossOriginRequestBlockedError`.
  The default (`true`) keeps 5.4.x behavior
- `NetKitManager(sensitiveHeaders: [...])` adds header names to redact from development HTTP logs

### Improvements

- Compatible with the whole `dio: ^5.8.0` range including Dio 5.10+ (`DioExceptionType.transformTimeout`
  maps to `RawHttpFailureType.timeout`); new Dio failure types no longer break compilation
- Development HTTP logging (`logInterceptorEnabled`) now uses a redacting interceptor instead of Dio's
  `LogInterceptor`: values of `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie`, common
  API-key/token headers, and `sensitiveHeaders` print as `[REDACTED]`, and request/response bodies
  are not printed
- In dev mode, a logger warning is emitted when the access token is about to be sent to a
  cross-origin absolute URL
- Documented that `uploadFile` reads the whole file into memory (so the request can be replayed after
  a token refresh); large or external uploads should use `RawHttpClient` with `StreamRawHttpBody`
- Resolved `parameter_assignments` analyzer findings

### Bug Fixes

- `uploadRawData` sent a `List<int>` that was not a `Uint8List` as text instead of raw bytes; the
  payload is now always sent as binary

# 5.4.1

### Bug Fixes

- Fix `requestList` treating HTTP 200 with an empty JSON array (`[]`) as an empty response body; empty lists are now parsed as `[]` instead of throwing `emptyResponseBodyError`

# 5.4.0

### Features

- Completer-based single-flight token refresh (concurrent 401s share one refresh)
- Per-request `skipTokenRefresh`, `allowRetryOn401`, and optional `idempotencyKey`
- RFC 9110-safe default: POST/PATCH are not replayed after 401 unless `allowRetryOn401: true`
- Optional `refreshTokenContentType: formUrlEncoded` for OAuth backends
- `requestVoid` accepts 204; `requestModel` / `requestList` throw `emptyResponseBodyError` on 204/empty body
- Added `uploadRawData` for direct binary uploads (`application/octet-stream`) without multipart encoding
- Added `uploadFile` convenience method to read a file from disk and upload as raw bytes (IO platforms only)

### Improvements

- Renamed `testMode` to `devMode` on `NetKitManager` and `NetKitParams` for clarity
- Retry requests merge per-request headers and forward `cancelToken` / progress callbacks
- Refresh requests tagged with internal `__isRefreshRequest` guard; normalized refresh path matching
- `devMode` logs a warning when access tokens contain whitespace (RFC 6750)
- Clarify that `loggerEnabled` and `logInterceptorEnabled` only take effect when `devMode` is true
- Added `invalidTokenResponseError` to `NetKitErrorParams` for refresh token parse failures
- Preserve wrapped `ApiException` messages when converting `DioException` to `ApiException`
- Run CI `dart analyze` from `packages/net-kit`
- Backfill CHANGELOG entries for 5.3.1–5.3.4
- Correct misleading docs (retry claim, `setAccessToken` example, `MIGRATION.md` token mapping)

### Bug Fixes

- Fix runtime crash when `containsAccessToken: false` is used with caller-provided `Map<String, String>` headers
- Fix refresh failure propagation (`Completer.completeError` no longer leaks uncaught errors)
- Fix retry limit so retried 401s do not trigger a second refresh
- Propagate refresh/retry `DioException` responses correctly to callers
- Fix metadata map mutation in `requestModelMeta` and `requestListMeta` (response maps are no longer modified in place)
- Fix `useDataKey: false` handling on meta endpoints to match non-meta methods and README
- Prevent double `Bearer` prefix when `setAccessToken` is called with a token that already includes the prefix
- Fix header race when `containsAccessToken: false` by applying token omission per request instead of mutating shared headers
- Parse `List<dynamic>` error message arrays in `ApiException.fromJson`
- Validate HTTP status codes after token-refresh retries (consistent with `_sendRequest`)
- Fail token refresh immediately with `noInternetError` when `internetStatusStream` reports offline
- Register the user-provided `interceptor` in `NetKitManager` (was stored but never added to Dio)
- Validate HTTP status codes in `uploadMultipartData` and `uploadFormData` (consistent with other request methods)
- Fail token refresh when the refresh response is missing a valid access token (previously succeeded silently)
- Remove fragile `package:dio/src/*` re-exports; public Dio types remain available via `package:dio/dio.dart`

### Deprecations

- `testMode` is deprecated in favor of `devMode` (alias retained for one release; removed in a future major version)

See [MIGRATION.md](MIGRATION.md) for auth refresh and `devMode` migration details.

# 5.3.4-dev

Pre-release for 5.3.4.

# 5.3.3-dev

Pre-release for 5.3.3.

# 5.3.2-dev

Pre-release for 5.3.2.

# 5.3.1

Patch release.

# 5.3.0

### **New Features**

- Added `useDataKey` parameter to all request methods (`requestModel`, `requestModelMeta`,
  `requestList`, `requestListMeta`, `uploadMultipartData`, `uploadFormData`)
- The `useDataKey` parameter allows you to control whether to use the configured `dataKey` wrapper
  for individual requests
- Default value is `true` to maintain backward compatibility
- When set to `false`, the response data will be used directly without dataKey extraction
- This is useful when you have different API endpoints that return data in different formats

### **Improvements**

- Enhanced flexibility for handling APIs with different response structures
- Better control over data extraction on a per-request basis

# 5.2.5

- updated sponsors

# 5.2.1

- Fixed issue with `NetKitManager` not properly handling the `loggerEnabled` option.

# 5.2.0

- Added `loggerEnabled` option to `NetKitManager` to enable or disable logging.

# 5.1.2

- Added more tests to make sure Refresh Token works as intended.

# 5.1.1

- updated README regarding `VoidModel` usage in `Upload`

# 5.1.0

- update type check for VoidModel in UploadManagerMixin

# 5.0.0

### **Breaking Changes**

- refresh token request is now sent via body.
  Reference: [Refreshing an Access Token](https://datatracker.ietf.org/doc/html/rfc6749#section-6)
- **removal**: `refreshTokenHeaderKey` is removed since refreshToken should not be in the
  header.
  Reference: [Refreshing an Access Token](https://datatracker.ietf.org/doc/html/rfc6749#section-6)

### **New Features**

- Added `removeAccessTokenBeforeRefresh` : A new top-level option in NetKitManager to remove the
  access token from headers during a token refresh.
- Added `accessTokenPrefix`: Allows you to define a custom token prefix (e.g., Bearer, Token) when
  setting the access token.
- Introduced `onBeforeRefreshRequest` callback: Lets you modify the refresh token request before it
  is sent — useful for injecting custom headers or modifying the request body.
  Introduced `NetKitRequestOptions`: A new abstraction to simplify and standardize refresh token
  request configuration.
- Introduced `onRefreshFailed` callback: This callback is triggered when the refresh token request
  fails.
  It provides a way to handle errors or perform specific actions when the refresh token process
  encounters issues.
- Added `metadataDataKey`: Enables support for parsing the actual data nested inside metadata
  wrappers from API responses.
- Added `requestModelMeta` and `requestListMeta` methods:

### **Improvements**

Improved error handling in **ApiException**

- Added `debugMessage` and `error` fields to provide more detailed diagnostics.
- Better support for **SocketException** and network-related errors via `ApiException.fromJson`

# 4.0.0

- `Breaking change`: removed authenticate method
- `Breaking change`: refresh tokens are now parsed from only body, since it is a common practice
  to return the new access token and, if needed, the new refresh token via body for more security.
  If you want to handle the refresh token manually, you can use add custom interceptor to handle
  the refresh token.
  **Reference
  **: [Issuing an Access Token: Successful Response](https://datatracker.ietf.org/doc/html/rfc6749#section-5.1)
- `Breaking change`: updated `accessTokenKey` as `accessTokenHeaderKey`
- `Breaking change`: updated `refreshTokenKey` as `refreshTokenHeaderKey`
- added `accessTokenBodyKey` to `NetKitManager` to parse the access token from the body
- added `refreshTokenBodyKey` to `NetKitManager` to parse the refresh token from the body

# 3.6.0

- deprecated `authenticate` method
- updated the code for the latest lint rules

# 3.5.1

- improved error handling in uploadMultipartData and uploadMultipartDataList methods

# 3.5.0

- fixed: uploadMultipartData and uploadMultipartDataList methods do not cover all error handling

# 3.4.3

- configured import of http-adapter to support wasm

# 3.4.2

- added @override to _logger in NetKitManager

# 3.4.1

- added logger.error in _sendRequest method

# 3.4.0

> Note: This release has breaking changes.

- `logLevel` is removed, since INetKitLogger instance injected to the NetKitManager. This is
  done to provide more flexibility to the developers to use their own logger.
- `loggerEnabled` is renamed to `logInterceptorEnabled` in `NetKitManager` to provide more clarity.
- added `logger` parameter to the `NetKitManager` to provide more flexibility to the developers to
  use their own logger.

# 3.3.4

- authentication issue fixed

# 3.3.2

- exported `VoidModel` class

# 3.3.1

- fixed `authentication` issue while parsing the response

# 3.3.0

- added `containsAccessToken` to requests

# 3.2.0

- fixed bug in _retryRequest with FormData

# 3.1.0

- added `VoidModel` class for void responses
- added `uploadMultipartData` method to upload files
- internal refactoring

## 3.0.9-dev

- internal refactoring

## 3.0.8-dev

- added `VoidModel` class

## 3.0.2-dev

- added `uploadMultipartData` method

# 3.0.1

- updated README.md

# 3.0.0

> Note: This release has breaking change.

- `Breaking change`: Renamed methods
    - `addBearerToken` to `setAccessToken`
    - `addRefreshToken` to `setRefreshToken`
    - `removeBearerToken` to `removeAccessToken`
- `Feature`: Added `refreshToken` feature. Refresh token is automatically refreshed when the access
  token is expired. Just add `refreshTokenPath` to the `NetKitManager` and it will automatically
  refresh the token. Note: the refresh token API in backend should return the new access token and,
  if needed, the new refresh token via headers for more security. If you want to handle the refresh
  token manually, you can use add custom interceptor to handle the refresh token.

## 2.4.5-dev

- updated error handling

## 2.4.4-dev

- added loggers in error handling interceptor
- fixed issue in error handling interceptor

## 2.4.3-dev

- added `refreshToken` feature

# 2.4.1, 2.4.2

- updated Readme (authentication example upd)

# 2.4.0

- added `authenticate` method and provided the example in README.md
- added `addRefreshToken` and `removeRefreshToken` methods to `NetKitManager`
- updated documentation on how to use `authenticate` method

## 2.3.3-dev

- updated documentation on how to use `authenticate` method

## 2.3.2-dev

- exported `AuthTokenModel` class

## 2.3.1-dev

- added `authenticate` method and provided the example in README.md
- added `addRefreshToken` and `removeRefreshToken` methods to `NetKitManager`

# 2.3.0

- fixed error `Cannot read properties of undefined (reading 'new')` in web with workaround
- added integration test for -release tags

## 2.2.0-dev

- fixed error `Cannot read properties of undefined (reading 'new')` in web with workaround
- added flutter-project to test web

# 2.1.2

- updated NetKitLogger to use only required imports from logger

# 2.1.0

> Note: This release has breaking change.

- downgraded SDK version to support more versions
- Breaking change: body's type parameter in `requestModel` and `requestList` methods is changed
  to `Map<String, dynamic>`

# 2.0.1

- updated README.md

# 2.0.0

> Note: This release has breaking changes.

- Removed the generic type parameter `<T>` from `INetKitModel`. When you extend `INetKitModel`,
  you don't need to provide the generic type parameter anymore.
- updated documentations

## 2.0.0-dev.2

- updated documentations

## 2.0.0-dev.1

> Note: This release has breaking changes.

- Removed the generic type parameter `<T>` from `INetKitModel`. When you extend `INetKitModel`,
  you don't need to provide the generic type parameter anymore.

# 1.8.3

- Exported `NetKitErrorParams` class

# 1.8.2

- exported `LogLevel` enum

# 1.8.1

- fixed data is not parsed to json.

# 1.8.0

- added JsonUnsupportedObjectError to handle unsupported objects in json
- added String for error message: `JsonUnsupportedObjectError`

# 1.7.0

- updated error handling to provide more information

# 1.6.2

- added more integration test cases
- added missing documentations

# 1.6.1

- added integration test from typicode

# 1.6.0

- log messages improved

## 1.6.0-dev.1

- updated HttpClientAdapter to support web
- added log messages

# 1.5.3

- added example
- updated error handling

# 1.5.2

- updated README.md
- declared platform supports

# 1.5.1

- updated README.md
- declared `web` support

# 1.5.0

- Stable: Added `internetStatusStream` to listen to the internet status

## 1.5.0-dev.2

- fixed no internet connection handler

## 1.5.0-dev.1

- Added `internetStatusStream` to listen to the internet status

# 1.4.1

> Note: This release has breaking changes.

- `NetKitErrorParams` introduced to handle error messages and status codes. It is required
  to provide internationalized error messages.
- `errorMessageKey` in the NetKitManager key is moved to `NetKitErrorParams` class as `messageKey`
- `errorStatusCodeKey` in the NetKitManager key is moved to `NetKitErrorParams` class as
  `statusCodeKey`

# 1.3.1

- added tasks to be done in the future

# 1.3.0

- Equality operator removed from `ApiException` class
- Updated README.md with correct examples
- Empty `json` error handling improved

# 1.2.2

- Equality operator added to `ApiException` class

# 1.2.1

- error handler updated

# 1.2.0

- error handler updated

# 1.1.1

- exported dio classes

# 1.1.0

- updated README.md
- exported ApiException
- updated documentation

# 1.0.0

> Note: This release has breaking changes.

- Return type of `requestModel` changed to `Future<T>`
- Return type of `requestList` changed to `Future<List<T>>`
- Return type of `requestVoid` changed to `Future<void>`
- `ApiException` is introduced as an exception that is thrown when an error occurs during the
  request

## 0.2.2

- integration tests added
- unit tests updated
- error handler improved

## 0.2.1

- updated README.md

## 0.2.0

- added documentations for public methods
- equatable dependency removed

## 0.1.3

- updated README.md: added image
- web dependency added

## 0.1.2

- fixed homepage and issue_tracker

## 0.1.1

- Updated README.md

## 0.1.0

- Initial release.