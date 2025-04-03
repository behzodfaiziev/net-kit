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

## Migration for Version 5.0.0

The v5.0.0 release of NetKit introduces several improvements and breaking changes, especially
related to token handling and RefreshTokenParams, to align
with [RFC 6749 §6](https://datatracker.ietf.org/doc/html/rfc6749#section-6). Below is a detailed
migration guide to help you upgrade smoothly.

### 🧩 1. refreshTokenPath has been moved

- **Before**:

```dart

final netKitManager = NetKitManager(
  baseUrl: 'https://api.example.com',
  refreshTokenPath: '/auth/refresh-token',
);
```

- **After**:

```dart

final netKitManager = NetKitManager(
  baseUrl: 'https://api.example.com',
  refreshTokenParams: RefreshTokenParams(
    refreshTokenPath: '/auth/refresh-token',
    body: {
      // Add your body parameters here. 
      // It will override the default body which contains the refresh token
    },
    headers: {
      // Add custom headers here if needed
    },
  ),
);
```

✅ This enables customization of the body, headers, and method used for refreshing.

### 🔁 2. **Breaking Change**: Refresh token is now sent in the body (not headers)

To comply with [RFC 6749 §6](https://datatracker.ietf.org/doc/html/rfc6749#section-6), the refresh
token is now included only in the request body, not headers. There is no need an action, as this is
handled under the hood.

### 🛡️ 3. Removed refreshTokenHeaderKey

The `refreshTokenHeaderKey` parameter has been removed entirely.

You no longer need to set the refresh token in headers manually.

### 🔑 4. **Breaking Change**: setAccessToken now does not include Bearer prefix

The `setAccessToken` method no longer includes the `Bearer` prefix in the token. This change allows
for more flexibility, as some APIs may not use the Bearer scheme.

- **Before**:

```dart
// netKitManager.setAccessToken("your_access_token');
```

- **After**:

```dart
// netKitManager.setAccessToken("Bearer your_access_token"); 
```