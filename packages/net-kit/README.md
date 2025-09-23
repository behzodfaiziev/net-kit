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
    * [**Available Request Methods**](#available-request-methods)
    * [**Request Examples**](#request-examples)
    * [**Why DataKey is Used**](#why-datakey-is-used)
    * [**DataKey Configuration**](#datakey-configuration)
    * [**Advanced Examples**](#advanced-examples)
    * [**Setting Tokens**](#setting-tokens)
    * [**User Logout**](#user-logout)
* [**Token Management**](#token-management)
    * [**Quick Token Setup**](#quick-token-setup)
    * [**Comprehensive Token Management**](#comprehensive-token-management)
* [**Logger Integration**](#logger-integration)
* [**Flutter Web Support**](#flutter-web-support)
* [Migration Guidance](#migration-guidance)
    * [**Feature Status**](#feature-status)
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
- 🌐 Flutter Web support with CORS configuration

## **Sponsors**

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

NetKitManager provides several methods for making HTTP requests. Each method is designed for
specific use cases and response types.

### **Available Request Methods**

| Method                | Description                           | Use Case                            |
|-----------------------|---------------------------------------|-------------------------------------|
| `requestModel`        | Request a single model                | Get a single resource               |
| `requestList`         | Request a list of models              | Get multiple resources              |
| `requestVoid`         | Send a request without expecting data | Delete, update operations           |
| `requestModelMeta`    | Request a model with metadata         | Get a resource with additional info |
| `requestListMeta`     | Request a list with metadata          | Get paginated data with metadata    |
| `uploadMultipartData` | Upload a single file                  | File uploads                        |
| `uploadFormData`      | Upload form data                      | Form submissions with files         |

### **Request Examples**

- *
  *📋 [Request a Single Model →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#service-layer-pattern)
  **
- *
  *📋 [Request a List of Models →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#service-layer-pattern)
  **
- *
  *📋 [Send a Void Request →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#service-layer-pattern)
  **
- *
  *📋 [Request Model with Metadata →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#service-layer-pattern)
  **
- *
  *📋 [Request List with Metadata (Pagination) →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#pagination)
  **
- *
  *📋 [Upload Multipart Data (Single File) →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#file-uploads)
  **
- *
  *📋 [Upload Form Data →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md#file-uploads)
  **

### **Why DataKey is Used**

Many APIs return responses in a wrapped format where the actual data is nested under a specific key.
For example:

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

Without DataKey configuration, you would need to manually extract the data from the `data` field in
every response. NetKit's DataKey feature automatically handles this extraction, making your code
cleaner and more maintainable.

### **DataKey Configuration**

The `useDataKey` parameter (default: `true`) allows you to control whether to use the configured
`dataKey` wrapper for individual requests. This is useful when you have different API endpoints that
return data in different formats.

- When `useDataKey: true` (default): Uses the configured `dataKey` to extract data from the response
- When `useDataKey: false`: Uses `response.data` directly, ignoring the `dataKey` configuration
- **Note:** This parameter has no effect if `dataKey` is not set in the NetKitManager configuration

Available on all request methods: `requestModel`, `requestModelMeta`, `requestList`,
`requestListMeta`, `uploadMultipartData`, and `uploadFormData`.

### **Advanced Examples**

For more detailed examples including pagination, error handling, and real-world use cases,
see [EXAMPLES.md](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/EXAMPLES.md).

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

NetKitManager provides comprehensive token management including automatic refresh, secure storage,
and RFC-compliant authentication flows.

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

📋 *
*[View Complete Token Management Guide →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/TOKEN_MANAGEMENT.md)
**

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

## **Flutter Web Support**

<details>
<summary>🌐 Click to expand Flutter Web CORS Support</summary>

NetKit provides built-in support for Flutter Web with proper CORS configuration. When using NetKit
with Flutter Web, you may encounter CORS (Cross-Origin Resource Sharing) issues when calling
third-party APIs.

### Quick Setup for Flutter Web

```dart
import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/manager/adapter/web_http_adapter.dart';

// For third-party APIs (recommended)
final netKitManager = NetKitManager(
  baseUrl: 'https://api.example.com',
  httpAdapter: const WebHttpAdapter(withCredentials: false),
);

// For your own API with authentication
final netKitManager = NetKitManager(
  baseUrl: 'https://your-api.com',
  httpAdapter: const WebHttpAdapter(withCredentials: true),
);
```

### Common CORS Issues

`DioException [connection error]: The connection errored: The XMLHttpRequest onError callback was called`
### Solutions

1. **Use appropriate credentials setting**:
     - `withCredentials: false` for public APIs (most third-party APIs)
     - `withCredentials: true` for your own authenticated APIs

2. **Configure server CORS headers** (if you control the API):
   ```javascript
   // Node.js/Express example
   app.use(cors({
     origin: ['http://localhost:3000', 'https://yourdomain.com'],
     credentials: false,
     methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
     allowedHeaders: ['Content-Type', 'Authorization']
   }));
   ```

3. **Handle CORS errors gracefully**:
   ```dart
   try {
     final response = await netKitManager.requestModel<MyModel>(
       path: '/data',
       method: RequestMethod.get,
       model: const MyModel(),
     );
   } on ApiException catch (e) {
     if (e.statusCode == 417) {
       // Likely a CORS error
       print('CORS Error: ${e.message}');
     }
   }
   ```

### 📖 Complete CORS Guide

For detailed information about CORS issues, solutions, and best practices, see our
comprehensive [Flutter Web CORS Guide](WEB_CORS_GUIDE.md).

</details>

# Migration Guidance

➡️ For detailed upgrade steps and breaking changes, see the
full [Migration Guide](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/MIGRATION.md).

## **Feature Status**

| *Feature*                                              | *Status* |
|:-------------------------------------------------------|:--------:|
| Internationalization support for error messages        |    ✅     |
| No internet connection handling                        |    ✅     |
| Basic examples and documentation                       |    ✅     |
| Comprehensive examples and use cases                   |    ✅     |
| MultiPartFile upload support                           |    ✅     |
| FormData upload support                                |    ✅     |
| Refresh Token implementation (RFC 6749/6750 compliant) |    ✅     |
| Customizable logging with log levels                   |    ✅     |
| Request retry logic for failed requests                |    ✅     |
| Comprehensive test coverage                            |    ✅     |
| Authentication and token management                    |    ✅     |
| DataKey configuration with per-request override        |    ✅     |
| Pagination support with metadata                       |    ✅     |
| Service layer pattern examples                         |    ✅     |
| Repository pattern examples                            |    ✅     |
| Error handling strategies                              |    ✅     |
| File upload with wrapper patterns                      |    ✅     |
| Token management documentation                         |    ✅     |

## **Contributing**

Contributions are welcome! Please open an [issue](https://github.com/behzodfaiziev/net-kit/issues)
or submit a [pull request](https://github.com/behzodfaiziev/net-kit/pulls).

## **License**

This project is licensed under the MIT License.
