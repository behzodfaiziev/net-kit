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
    * [**Custom Void Models in Uploading**](#custom-void-models-in-uploading)
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
  * [**Logger Integration**](#logger-integration)
* [Migration Guidance](#migration-guidance)
  * [**Planned Enhancements**](#planned-enhancements)
  * [**Contributing**](#contributing)
  * [**License**](#license)
<!-- TOC -->

</details>  

## **Features**

- 🔄 Automatic token refresh with queue-safe retry
- ⚙️ `onBeforeRefreshRequest` to mutate refresh payload
- 🛠 Parsing responses into models or lists using `INetKitModel`
- 🧪 Configurable base URLs for development and production
- 🌐 Internationalization support for error messages
- 📦 Multipart upload support
- 📋 Extensible logger integration

## **Sponsors**

A big thanks to our awesome sponsors for keeping this project going!️ Want to help out? Consider
becoming a [sponsor](https://github.com/sponsors/behzodfaiziev/)!

<table style="background-color: white; border: 1px solid black">
    <tbody>
        <tr>
            <td align="center" style="border: 1px solid black">
                <a href="https://westudio.dev"><img src="https://github.com/user-attachments/assets/a7ce889d-340f-4c84-8cb1-6a94c31bacc5" width="225"/></a>
            </td>
            <td align="center" style="border: 1px solid black">
                <a href="https://jurnalle.com"><img src="https://github.com/user-attachments/assets/d3463ab8-f7fa-4d75-8595-9335e59a9cad" width="225"/></a>
            </td>
            <td align="center" style="border: 1px solid black">
                <a href="https://vremica.com"><img src="https://github.com/user-attachments/assets/25942faf-45dc-44cf-8422-2d2eb2711ac0" width="225"/></a>
            </td>

</table>

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

## **Refresh Token**

NetKitManager provides a robust and RFC-compliant refresh token mechanism to ensure seamless and
uninterrupted API communication, even when access tokens expire.

1. When a request fails with a 401 Unauthorized, NetKit will automatically:
2. Pause the failing request and any subsequent requests.
3. Attempt to refresh the access token via the configured refreshTokenPath.
4. Retry the failed requests using the new token upon successful refresh.

### **Refresh Token Initialization**

To use the refresh token feature, you need to initialize the NetKitManager with the following
parameters:

| Parameter                        | Required | Description                                                                |
|----------------------------------|----------|----------------------------------------------------------------------------|
| `refreshTokenPath`               | ✅        | Endpoint to request a new access token using the refresh token.            |
| `onTokenRefreshed`               | ✅        | Callback triggered after tokens are successfully refreshed.                |
| `refreshTokenBodyKey`            | ➖        | Key for the refresh token in the refresh body (default: "refreshToken").   |
| `accessTokenBodyKey`             | ➖        | Key for the access token in the refresh body (default: "accessToken").     |
| `removeAccessTokenBeforeRefresh` | ➖        | Whether to strip access token header during token refresh (default: true). |
| `accessTokenPrefix`              | ➖        | Prefix added to accessToken in headers (default: "Bearer").                |
| `onBeforeRefreshRequest`         | ➖        | Allows modifying headers/body before refresh is sent.                      |

### **Refresh Token Example**

```dart

final netKitManager = NetKitManager(
  baseUrl: 'https://api.<URL>.com',
  devBaseUrl: 'https://dev.<URL>.com',
  refreshTokenPath: '/auth/refresh-token',

  /// Called after a successful refresh
  onTokenRefreshed: (authToken) async {
    await secureStorage.saveTokens(
      accessToken: authToken.accessToken,
      refreshToken: authToken.refreshToken,
    );
  },

  /// Optional: remove the Authorization header before making refresh request
  removeAccessTokenBeforeRefresh: true,

  /// Optional: override the default prefix "Bearer"
  accessTokenPrefix: 'Token',

  /// Optional: customize refresh request before it is sent
  onBeforeRefreshRequest: (options) {
    options.headers['Custom-Header'] = 'MyValue';
    options.body['client_id'] = 'your_client_id';
    options.body['client_secret'] = 'your_secret';
  },
);
```

### **How refresh token works**

The refresh token mechanism in `NetKitManager` ensures that your access tokens are automatically
refreshed when they expire, allowing for seamless and uninterrupted API requests. Here’s how it
works:

🔍 **Token Expiry Detection:**

- When an API request fails with a 401 Unauthorized status code, NetKitManager automatically detects
  that the access token has likely expired.

🔄 **Token Refresh Request:**

- It then sends a request to the configured refreshTokenPath endpoint to obtain new access and
  refresh tokens.
- The request body includes the current refresh token, and optionally other custom fields.

✅ **Updating Tokens:**

- Once new tokens are received:
    - The Authorization header (or other configured header) is updated with the new access token.
    - The onTokenRefreshed callback is triggered so you can store the new tokens securely.

🔁 **Retrying the Original Request:**

- The original request that failed is automatically retried with the new access token.
- Any other requests that were waiting during token refresh are also retried in order.

This process ensures that your application can continue to make authenticated requests without
requiring user intervention when tokens expire.

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
  logger: NetworkLogger(),
  // ... other parameters
);
```

# Migration Guidance

➡️ For detailed upgrade steps and breaking changes, see the full [Migration Guide](./MIGRATION.md).

## **Planned Enhancements**

| *Feature*                                                   | *Status* |
|:------------------------------------------------------------|:--------:|
| Internationalization support for error messages             |    ✅     |@
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
