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