![h)](https://github.com/user-attachments/assets/d8115ef2-4783-4d2d-88de-df57df40112f)

![Version](https://img.shields.io/pub/v/net_kit)
![License](https://img.shields.io/badge/license-MIT-green)
![Contributions welcome](https://img.shields.io/badge/contributions-welcome-orange)
![GitHub Sponsors](https://img.shields.io/badge/sponsors-welcome-yellow)
![RFC Compliant](https://img.shields.io/badge/standards-RFC%206749%2C%206750-blue.svg)

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
  * [📜 **Standards Compliance**](#-standards-compliance)
    * [🔐 RFC Standards](#-rfc-standards)
      * [📣 Help Us Stay Compliant](#-help-us-stay-compliant)
* [Migration Guidance](#migration-guidance)
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

## 📜 **Standards Compliance**

`NetKit` is built with security and interoperability in mind, and follows the official
specifications for modern API authentication:

### 🔐 RFC Standards

| RFC                                                           | Description                       | Link                                                                |
|---------------------------------------------------------------|-----------------------------------|---------------------------------------------------------------------|
| **[RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749)** | OAuth 2.0 Authorization Framework | Defines how clients securely obtain and use access & refresh tokens |
| **[RFC 6750](https://datatracker.ietf.org/doc/html/rfc6750)** | Bearer Token Usage                | Specifies how to transmit access tokens in HTTP requests            |
| **[RFC 7519](https://datatracker.ietf.org/doc/html/rfc7519)** | JSON Web Token (JWT)              | Structure and use of signed tokens (used if JWTs are supported)     |

#### 📣 Help Us Stay Compliant

If you find any behavior in NetKit that appears to be non-compliant with any of the above RFCs,
please open an issue with a clear reference to the relevant RFC and section.

We’re committed to improving and welcome community-driven compliance insights!

# Migration Guidance
➡️ For detailed upgrade steps and breaking changes, see the full [Migration Guide](./MIGRATION.md).

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