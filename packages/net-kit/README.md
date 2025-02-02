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
  * [**Sponsors**](#sponsors)
  * [**Getting started**](#getting-started)
    * [**Initialize**](#initialize)
    * [**Extend the model**](#extend-the-model)
    * [**Logger Integration**](#logger-integration)
  * [**Sending requests**](#sending-requests)
      * [**Request a Single Model**](#request-a-single-model)
      * [**Request a List of Models**](#request-a-list-of-models)
      * [**Send a void Request**](#send-a-void-request)
    * [**Setting Tokens**](#setting-tokens)
    * [**User Logout**](#user-logout)
  * [**Refresh Token**](#refresh-token)
    * [**Refresh Token Initialization**](#refresh-token-initialization)
    * [**Refresh Token Example**](#refresh-token-example)
    * [**How refresh token works**](#how-refresh-token-works)
* [Migration Guidance](#migration-guidance)
  * [authenticate Method Deprecation: v3.6.0](#authenticate-method-deprecation-v360)
    * [Why is `authenticate` Deprecated?](#why-is-authenticate-deprecated)
    * [How to Migrate](#how-to-migrate)
  * [**Planned Enhancements**](#planned-enhancements)
  * [**Contributing**](#contributing)
  * [**License**](#license)
<!-- TOC -->

</details>  

## **Features**

- 🔄 Automatic token refresh
- 🛠 Parsing responses into models or lists of models using `INetKitModel`
- 🧪 Configurable base URLs for development and production
- 🌐 Internationalization support for error messages
## **Sponsors**

A big thanks to our awesome sponsors for keeping this project going!️ Want to help out? Consider
becoming a [sponsor](https://github.com/sponsors/behzodfaiziev/)!

<img src="https://github.com/user-attachments/assets/d3463ab8-f7fa-4d75-8595-9335e59a9cad" alt="Jurnalle" width="150px">

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

### **Logger Integration**

The `NetKitManager` uses a logger internally, for example, during the refresh token stages. To add
custom logging, you need to create a class that implements the `INetKitLogger` interface. Below is
an example of how to create a `NetworkLogger` class:

You can find the full example
of
`NetworkLogger` [here](https://github.com/behzodfaiziev/net-kit/blob/main/flutter_integration_test/lib/core/network/logger/network_logger.dart).

```dart

final netKitManager = NetKitManager(
  baseUrl: 'https://api.<URL>.com',
  logger: NetworkLogger(),
  // ... other parameters
);
```

## **Sending requests**

#### **Request a Single Model**

```dart
Future<RandomUserModel> getRandomUser() async {
  try {
    final result = await netKitManager.requestModel<RandomUserModel>(
      path: '/api',
      method: RequestMethod.get,
      model: const RandomUserModel(),
    );
    return result;
  }

  /// Catch the ApiException and handle it
  on ApiException catch (e) {
    /// Handle the error: example is to throw the error
    throw Exception(e.message);
  }
}
```

#### **Request a List of Models**

```dart
Future<List<ProductModel>> getProducts() async {
  try {
    final result = await netKitManager.requestList<ProductModel>(
      path: '/products',
      method: RequestMethod.get,
      model: const ProductModel(),
    );
    return result;
  }

  /// Catch the ApiException and handle it
  on ApiException catch (e) {
    /// Handle the error: example is to throw the error
    throw Exception(e.message);
  }
}
```

#### **Send a void Request**

```dart
Future<void> deleteProduct() async {
  try {
    await netKitManager.requestVoid(
      path: '/products',
      method: RequestMethod.delete,
    );
    return;
  }

  /// Catch the ApiException and handle it
  on ApiException catch (e) {
    /// Handle the error: example is to throw the error
    throw Exception(e.message);
  }
}
```
### **Setting Tokens**

The **NetKitManager** allows you to set and manage access and refresh tokens, which are essential
for
authenticated API requests. Below are the methods provided to set, update, and remove tokens.

**Setting Access and Refresh Tokens**

To set the access and refresh tokens, use the `setAccessToken` and `setRefreshToken` methods. These
tokens will be added to the headers of every request made by the NetKitManager.
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

This method ensures that the tokens are removed from the headers, effectively logging out the user.

## **Refresh Token**

The NetKitManager provides a built-in mechanism for handling token refresh. This feature ensures
that your access tokens are automatically refreshed when they expire, allowing for seamless and
uninterrupted API requests.

### **Refresh Token Initialization**

To use the refresh token feature, you need to initialize the NetKitManager with the following
parameters:

- `refreshTokenPath`: The API endpoint used to refresh the tokens.
- `onTokenRefreshed`: A callback function that is called when the tokens are successfully
  refreshed.

### **Refresh Token Example**

```dart

final netKitManager = NetKitManager(
  baseUrl: 'https://api.<URL>.com',
  devBaseUrl: 'https://dev.<URL>.com',
  loggerEnabled: true,
  testMode: true,
  refreshTokenPath: '/auth/refresh-token',
  onTokenRefreshed: (authToken) async {
    /// Save the new access token to the storage
  },
  // ... other parameters
);
```

### **How refresh token works**

The refresh token mechanism in `NetKitManager` ensures that your access tokens are automatically
refreshed when they expire, allowing for seamless and uninterrupted API requests. Here’s how it
works:

**Token Expiry Detection:**

- When an API request fails due to an expired access token, the `NetKitManager` detects this
  failure(401 status code) and automatically triggers the refresh token process.

**Token Refresh Request:**

- The NetKitManager automatically sends a request to the refreshTokenPath endpoint to obtain new
  access and refresh tokens.

**Updating Tokens:**

- Upon receiving new tokens, NetKitManager updates headers with the new access token.
- The onTokenRefreshed callback is called with new tokens, allowing you to store them securely.

**Retrying the Original Request:**

- The original API request that failed due to token expiry is retried with the new access token.

This process ensures that your application can continue to make authenticated requests without
requiring user intervention when tokens expire.

# Migration Guidance

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
  final response = await _network.requestModel<AuthResultModel>(
    path: '/auth/sign-in',
    method: RequestMethod.post,
    model: AuthResultModel(),
    body: signInParams.toJson(),
  );

  // Assuming `AuthResultModel` contains both user info and tokens
  final authToken = AuthTokenModel.fromJson(response.toJson());

  return (response, authToken);
}
```

## **Planned Enhancements**

| *Feature*                                                   | *Status* |
|:------------------------------------------------------------|:--------:|
| Internationalization support for error messages             |    ✅     |
| No internet connection handling                             |    ✅     |
| Provide basic example                                       |    ✅     |
| Provide more examples and use cases in the documentation    |    ✅     |
| MultiPartFile upload support                                |    ✅     |
| Refresh Token implementation                                |    ✅     |
| Enhance logging capabilities with customizable log levels   |    ✅     |
| Implement retry logic for failed requests                   |    🟡    |
| Add more tests to ensure the package is robust and reliable |    ✅     |
| Authentication Feature                                      |    ✅     |
| Add Clean Architecture example                              |    🟡    |

## **Contributing**

Contributions are welcome! Please open an [issue](https://github.com/behzodfaiziev/net-kit/issues)
or submit a [pull request](https://github.com/behzodfaiziev/net-kit/pulls).

## **License**

This project is licensed under the MIT License.