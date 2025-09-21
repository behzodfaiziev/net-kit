# Token Management

This document provides comprehensive guidance for implementing token management with NetKitManager.

## RFC Compliance

NetKitManager's token management implementation follows these RFC standards:

- **[RFC 6749 - OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749)**
- **[RFC 6750 - OAuth 2.0 Bearer Token Usage](https://tools.ietf.org/html/rfc6750)**
- **[RFC 7235 - HTTP Authentication](https://tools.ietf.org/html/rfc7235)**

### Additional Standards

- **Token Storage Security**: Implements secure token storage patterns (application-level, not HTTP cookies)
- **Request Queuing**: Handles concurrent requests during token refresh to prevent race conditions
- **Error Handling**: Comprehensive error handling for authentication failures and network issues

> **Note**: If you identify any RFC compliance issues or need additional standards support, please open an issue on
> the [NetKit repository](https://github.com/behzodfaiziev/net-kit) so we can address them in future releases.

### Security Standards Compliance

- **Token Expiration**: Implements proper token expiration handling as per OAuth 2.0 specifications
- **Secure Storage**: Uses platform-specific secure storage mechanisms (Keychain on iOS, Keystore on Android)
- **Token Refresh**: Implements automatic token refresh with proper error handling and fallback mechanisms
- **HTTPS Enforcement**: Ensures all token-related communications use HTTPS as required by OAuth 2.0
- **Scope Validation**: Supports OAuth 2.0 scope validation for fine-grained access control

## Token Refresh Configuration

NetKitManager provides a robust and RFC-compliant refresh token mechanism to ensure seamless and uninterrupted API communication, even when access tokens expire.

### How Token Refresh Works

1. When a request fails with a 401 Unauthorized, NetKit will automatically:
2. Pause the failing request and any subsequent requests.
3. Attempt to refresh the access token via the configured refreshTokenPath.
4. Retry the failed requests using the new token upon successful refresh.

### Refresh Token Initialization

To use the refresh token feature, you need to initialize the NetKitManager with the following parameters:

| Parameter                        | Required | Description                                                                |
|----------------------------------|----------|----------------------------------------------------------------------------|
| `refreshTokenPath`               | ✅        | Endpoint to request a new access token using the refresh token.            |
| `onTokenRefreshed`               | ✅        | Callback triggered after tokens are successfully refreshed.                |
| `refreshTokenBodyKey`            | ➖        | Key for the refresh token in the refresh body (default: "refreshToken").   |
| `accessTokenBodyKey`             | ➖        | Key for the access token in the refresh body (default: "accessToken").     |
| `removeAccessTokenBeforeRefresh` | ➖        | Whether to strip access token header during token refresh (default: true). |
| `accessTokenPrefix`              | ➖        | Prefix added to accessToken in headers (default: "Bearer").                |
| `onBeforeRefreshRequest`         | ➖        | Allows modifying headers/body before refresh is sent.                      |

<details>
<summary>🔐 <strong>Basic Token Refresh Setup</strong></summary>

```dart
final netKitManager = NetKitManager(
  baseUrl: 'https://api.example.com',
  devBaseUrl: 'https://dev.example.com',
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

  onRefreshFailed: (error) async {
    // Handle refresh failure - redirect to login
    await tokenManager.clearTokens();
    // Navigate to login screen
  },

  onBeforeRefreshRequest: (options) {
    // Add custom headers or modify request body
    options.headers['X-Client-Version'] = '1.0.0';
  },
);
```

</details>

### Detailed Token Refresh Process

The refresh token mechanism in `NetKitManager` ensures that your access tokens are automatically refreshed when they expire, allowing for seamless and uninterrupted API requests. Here's how it works:

🔍 **Token Expiry Detection:**

- When an API request fails with a 401 Unauthorized status code, NetKitManager automatically detects that the access token has likely expired.

🔄 **Token Refresh Request:**

- It then sends a request to the configured refreshTokenPath endpoint to obtain new access and refresh tokens.
- The request body includes the current refresh token, and optionally other custom fields.

✅ **Updating Tokens:**

- Once new tokens are received:
    - The Authorization header (or other configured header) is updated with the new access token.
    - The onTokenRefreshed callback is triggered so you can store the new tokens securely.

🔁 **Retrying the Original Request:**

- The original request that failed is automatically retried with the new access token.
- Any other requests that were waiting during token refresh are also retried in order.

This process ensures that your application can continue to make authenticated requests without requiring user intervention when tokens expire.

<details>
<summary>🔧 <strong>Advanced Token Refresh Configuration</strong></summary>

```dart

final netKitManager = NetKitManager(
  baseUrl: 'https://api.example.com',
  refreshTokenPath: '/auth/refresh',

  // Custom refresh token request body
  refreshTokenBody: (refreshToken) =>
  {
    'refresh_token': refreshToken,
    'grant_type': 'refresh_token',
  },

  // Custom headers for refresh requests
  refreshTokenHeaders: {
    'Content-Type': 'application/json',
    'X-Client-Version': '1.0.0',
  },

  onTokenRefreshed: (authToken) async {
    // Save new tokens securely
    await secureStorage.write(
      key: 'access_token',
      value: authToken.accessToken!,
    );
    await secureStorage.write(
      key: 'refresh_token',
      value: authToken.refreshToken!,
    );

    // Update local state
    _currentUser.updateTokens(authToken);
  },

  onRefreshFailed: (error) async {
    // Log the error
    logger.error('Token refresh failed: ${error.message}');

    // Clear all stored tokens
    await secureStorage.deleteAll();
  },

  onBeforeRefreshRequest: (options) {
    // Add analytics tracking
    analytics.track('token_refresh_attempt');

    // Add custom headers
    options.headers['X-Request-ID'] = uuid.v4();
  },
);
```

</details>

## Best Practices

### **Secure Storage**

- Always use secure storage for sensitive tokens
- Never store tokens in plain text

### **Security Considerations**

- Use HTTPS for all token-related communications
- Implement proper token expiration policies
- Consider using short-lived access tokens with longer-lived refresh tokens
- Implement proper fallback mechanisms for token failures

This comprehensive token management guide ensures secure and reliable authentication in your Flutter applications using
NetKitManager.
