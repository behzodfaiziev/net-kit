![h)](https://github.com/user-attachments/assets/d8115ef2-4783-4d2d-88de-df57df40112f)

![Version](https://img.shields.io/pub/v/net_kit)
![License](https://img.shields.io/badge/license-MIT-green)
![Contributions welcome](https://img.shields.io/badge/contributions-welcome-orange)
![GitHub Sponsors](https://img.shields.io/badge/sponsors-welcome-yellow)

## **Contents**

<summary>Click to expand</summary>

<!-- TOC -->
  * [**Contents**](#contents)
  * [**Features**](#features)
  * [**Sponsors**](#sponsors)
  * [**Getting started**](#getting-started)
    * [Initialize](#initialize)
    * [Extend the model](#extend-the-model)
  * [**Sending requests**](#sending-requests)
      * [Request a Single Model](#request-a-single-model)
      * [Request a List of Models](#request-a-list-of-models)
      * [Send a void Request](#send-a-void-request)
  * [**Authentication Methods**](#authentication-methods)
    * [Sign In with Credentials](#sign-in-with-credentials)
    * [Sign Up](#sign-up)
    * [Sign In with Social Accounts](#sign-in-with-social-accounts)
    * [Setting Tokens](#setting-tokens)
    * [User Logout](#user-logout)
  * [**Refresh Token**](#refresh-token)
    * [Refresh Token Initialization](#refresh-token-initialization)
    * [Refresh Token Example](#refresh-token-example)
    * [How refresh token works](#how-refresh-token-works)
  * [**Planned Enhancements**](#planned-enhancements)
  * [**Contributing**](#contributing)
  * [**License**](#license)
<!-- TOC -->

</details>  

## **Features**

- 📝 Supports various HTTP methods (GET, POST, PUT, DELETE, PATCH)
- 🌐 Configurable base URLs for development and production
- 📊 Logging of network requests and responses
- ❗ Error handling and response validation
- 🛠 Parsing responses into models or lists of models using `INetKitModel`

## **Sponsors**

A big thanks to our awesome sponsors for keeping this project going!️ Want to help out? Consider
becoming a [sponsor](https://github.com/sponsors/behzodfaiziev/)!

<img src="https://github.com/user-attachments/assets/d3463ab8-f7fa-4d75-8595-9335e59a9cad" alt="Jurnalle" width="200px">

## **Getting started**

### Initialize

Initialize the NetKitManager with the parameters:

```dart
import 'package:net_kit/net_kit.dart';

final netKitManager = NetKitManager(
  baseUrl: 'https://api.<URL>.com',
  devBaseUrl: 'https://dev.<URL>.com',
  loggerEnabled: true,
  testMode: true,
);
```

### Extend the model

Requests such as: `requestModel` and`requestList` require the model to
extend `INetKitModel` in order to be used with the NetKitManager. By extending, `INetKitModel`
`fromJson` and `toJson` methods will be needed to be implemented, so the model can be serialized and
deserialized.

```dart
class TodoModel extends INetKitModel {}
```

## **Sending requests**

#### Request a Single Model

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

#### Request a List of Models

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

#### Send a void Request

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

## **Authentication Methods**

The `authenticate()` method in `NetKitManager` allows you to handle all types of authentication
needs, including user sign-in, user sign-up, and social logins (Google, Facebook, etc.). Below are
examples of how to use it for each scenario.

### Sign In with Credentials

This method authenticates users with their username and password by providing SignInRequestModel.
After a successful sign-in, it
returns the user model and authentication tokens.

**Example:**

```dart
Future<UserModel> loginWithCredentials(SignInRequestModel signInRequest) async {
  try {
    final result = await netKitManager.authenticate<UserModel>(
      path: '/auth/signin', // API endpoint for sign-in
      method: RequestMethod.post, // POST request for login
      model: UserModel(), // User model to parse response
      body: signInRequest.toJson(), // Credentials
    );

    final user = result.$1; // Parsed user model
    final authToken = result.$2; // AuthTokenModel with access and refresh tokens

    print('User signed in: ${user.name}');
    print('Access token: ${authToken.accessToken}');

    return user;
  } catch (e) {
    throw Exception('Login failed: $e');
  }
}
```

### Sign Up

This method registers a new user by sending their details to the server. After successful
registration, the user model and authentication tokens are returned. Note: backend API may
or may not return the userModel and authTokens after sign-up. So its userModel or authTokens can be
null.

**Example:**

```dart
Future<UserModel> signUpUser(SignUpRequestModel signUpRequest) async {
  try {
    final result = await netKitManager.authenticate<UserModel>(
      path: '/auth/signup', // API endpoint for sign-up
      method: RequestMethod.post, // POST request for sign-up
      model: UserModel(), // User model to parse response
      body: signUpRequest.toJson(), // User details
    );

    final user = result.$1; // Parsed user model
    final authToken = result.$2; // AuthTokenModel with access and refresh tokens

    print('User signed up: ${user.name}');
    print('Access token: ${authToken.accessToken}');

    return user;
  } catch (e) {
    throw Exception('Sign up failed: $e');
  }
}
```

### Sign In with Social Accounts

This method allows users to authenticate using their social media accounts, such as Google,
Facebook, etc. It requires the access token received from the social provider, which is then sent to
the server for validation.

**Example for Google Sign-In:**

```dart
Future<UserModel> loginWithGoogle(String googleAccessToken) async {
  try {
    final result = await netKitManager.authenticate<UserModel>(
      path: '/auth/social-login', // API endpoint for social login
      method: RequestMethod.post, // POST request for login
      model: UserModel(), // User model to parse response
      socialAccessToken: googleAccessToken, // The Google access token
    );

    final user = result.$1; // Parsed user model
    final authToken = result.$2; // AuthTokenModel containing access and refresh tokens

    print('User signed in with Google: ${user.name}');
    print('Access token: ${authToken.accessToken}');

    return user;
  } catch (e) {
    throw Exception('Google login failed: $e');
  }
}

```

**How It Works:**

- `signInWithSocial`:
    - `socialAccessToken`: This is the token provided by the social login provider (e.g., Google,
      Facebook).
    - The server will validate the token with the social provider and, if successful, will return
      the user's profile (model) and authentication tokens.
    - The authToken contains both the access token (for authorized requests) and the refresh token (
      for obtaining a new access token when the current one expires).

### Setting Tokens

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

### User Logout

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

### Refresh Token Initialization

To use the refresh token feature, you need to initialize the NetKitManager with the following
parameters:

- `refreshTokenPath`: The API endpoint used to refresh the tokens.
- `onTokenRefreshed`: A callback function that is called when the tokens are successfully
  refreshed.

### Refresh Token Example

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
);
```

### How refresh token works

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