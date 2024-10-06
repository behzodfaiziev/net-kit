## 2.1.2

- updated NetKitLogger to use only required imports from logger

## 2.1.0

> Note: This release has breaking change.

- downgraded SDK version to support more versions
- Breaking change: body's type parameter in `requestModel` and `requestList` methods is changed
  to `Map<String, dynamic>`

## 2.0.1

- updated README.md

## 2.0.0

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

## 1.8.3

- Exported `NetKitErrorParams` class

## 1.8.2

- exported `LogLevel` enum

## 1.8.1

- fixed data is not parsed to json.

## 1.8.0

- added JsonUnsupportedObjectError to handle unsupported objects in json
- added String for error message: `JsonUnsupportedObjectError`

## 1.7.0

- updated error handling to provide more information

## 1.6.2

- added more integration test cases
- added missing documentations

## 1.6.1

- added integration test from typicode

## 1.6.0

- log messages improved

## 1.6.0-dev.1

- updated HttpClientAdapter to support web
- added log messages

## 1.5.3

- added example
- updated error handling

## 1.5.2

- updated README.md
- declared platform supports

## 1.5.1

- updated README.md
- declared `web` support

## 1.5.0

- Stable: Added `internetStatusStream` to listen to the internet status

## 1.5.0-dev.2

- fixed no internet connection handler

## 1.5.0-dev.1

- Added `internetStatusStream` to listen to the internet status

## 1.4.1

> Note: This release has breaking changes.

- `NetKitErrorParams` introduced to handle error messages and status codes. It is required
  to provide internationalized error messages.
- `errorMessageKey` in the NetKitManager key is moved to `NetKitErrorParams` class as `messageKey`
- `errorStatusCodeKey` in the NetKitManager key is moved to `NetKitErrorParams` class as
  `statusCodeKey`

## 1.3.1

- added tasks to be done in the future

## 1.3.0

- Equality operator removed from `ApiException` class
- Updated README.md with correct examples
- Empty `json` error handling improved

## 1.2.2

- Equality operator added to `ApiException` class

## 1.2.1

- error handler updated

## 1.2.0

- error handler updated

## 1.1.1

- exported dio classes

## 1.1.0

- updated README.md
- exported ApiException
- updated documentation

## 1.0.0

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