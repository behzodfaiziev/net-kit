# Token Management

This document provides comprehensive guidance for implementing token management with NetKitManager.

## RFC Compliance

NetKitManager's token management implementation follows these RFC standards:

- **[RFC 6749 - OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749)**
- **[RFC 6750 - OAuth 2.0 Bearer Token Usage](https://tools.ietf.org/html/rfc6750)**
- **[RFC 7235 - HTTP Authentication](https://tools.ietf.org/html/rfc7235)**

### Additional Standards

- **Token Storage Security**: Implements secure token storage patterns (application-level, not HTTP cookies)
- **Request Queuing**: Handles concurrent requests during token refresh via Completer single-flight
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

1. When a request with `AuthPolicy.inherit` or `AuthPolicy.required` fails with a 401 Unauthorized
   and a `refreshTokenPath` is configured, NetKit will automatically:
2. Start one refresh request (or join the one already in flight).
3. Update the stored access token (and refresh token) from the refresh response.
4. Retry the failed request once with the new token (GET/PUT/DELETE by default; POST/PATCH only
   with `allowRetryOn401: true`, RFC 9110). Streamed bodies (`uploadFile`, file parts created
   with `NetKitMultipartFile.fromPath` / `fromStream`) are reopened and sent again in full.

Concurrent 401s share a single refresh (single-flight). Without a `refreshTokenPath` the 401 is
returned to the caller unchanged.

### When the session ends (and when it does not)

There are two different 401s, and only one of them ends the session:

| Event | Meaning | What NetKit does |
|-------|---------|------------------|
| An ordinary API request returns 401 | The access token may be stale | Starts (or joins) one refresh and retries once. The session is **not** ended. |
| The **refresh endpoint** returns 401 | The refresh credential was rejected | Clears the stored access and refresh tokens, calls `onSessionInvalidated` **once**, and fails every waiting request with `ApiFailureType.sessionInvalidated` |
| The refresh fails any other way | Temporary or server-side problem | Keeps both tokens, fails the waiting requests with the real cause, and refreshes again on the next 401 |

"Any other way" covers: device offline, DNS failure, TLS failure, timeouts, cancellation, `429`,
`5xx`, any other `4xx` (including `400` and `403`), a malformed response, and a `2xx` without an
access token. None of these clear tokens or call `onSessionInvalidated`. The failure reaches the
caller with its own `ApiFailureType` (`transport`, `timeout`, `cancelled`, `response`,
`decoding`, ...) and `ApiException.fromRefresh == true`.

Sign the user out in `onSessionInvalidated`, and nowhere else:

```dart
final netKitManager = NetKitManager(
  baseUrl: 'https://api.example.com',
  refreshTokenPath: '/auth/refresh',
  onSessionInvalidated: (exception) async {
    // Only reached when the refresh endpoint answered 401.
    await secureStorage.deleteAll();
    router.goToSignIn();
  },
);
```

Details:

- The decision is taken from the HTTP status the transport reported for the refresh response, not
  from an exception type, message, or interceptor-modified response.
- Concurrent requests waiting on the same refresh all receive the same `sessionInvalidated`
  failure; the callback runs once.
- After a session is invalidated, further 401s are returned to the caller without another
  refresh attempt until the application stores new credentials (`setAccessToken`,
  `setRefreshToken`, `addHeader`, ...).
- If the application stores new credentials while a refresh is in flight, that refresh's result is
  discarded: new tokens do not overwrite the newer ones, and a 401 for the old refresh token does
  not end the new session.
- The callback is not awaited. Errors it throws are logged and ignored, so it cannot block or
  corrupt pending requests.
- Cancelling a request that is waiting for a refresh stops that request immediately; the shared
  refresh continues for the other requests, and the cancelled request is not retried.

### Refresh request origin

The refresh request always targets the API origin (`baseUrl`, or `devBaseUrl` in dev mode), even
when `allowCrossOriginRequests` is true and even if `onBeforeRefreshRequest` or an interceptor
points it elsewhere: such a request fails with `invalidRequest` before anything is sent. Redirects
of the refresh request are followed only within the API origin. On the web, where the browser
follows redirects itself, a refresh response that came from a redirect is rejected
(`unverifiedRedirectError`) instead of being trusted.

### Per-request auth policy

```dart
// Public endpoint: no access token, and a 401 is not "refresh me"
await netKitManager.requestModel(
  path: '/public/profile',
  method: RequestMethod.get,
  model: const ProfileModel(),
  authPolicy: AuthPolicy.none,
);

// Mandatory authentication: fail fast when no token is stored
await netKitManager.requestModel(
  path: '/account',
  method: RequestMethod.get,
  model: const AccountModel(),
  authPolicy: AuthPolicy.required,
);

// Idempotent POST: allow one replay after refresh
await netKitManager.requestVoid(
  path: '/orders',
  method: RequestMethod.post,
  body: {'item': 'x'},
  allowRetryOn401: true,
  idempotencyKey: 'my-key',
);
```

| `AuthPolicy` | Access token | On 401 |
|--------------|--------------|--------|
| `inherit` (default) | Sent when stored | Refresh once and retry |
| `none` | Never sent (a caller-supplied `Authorization` header is stripped too) | Returned as `ApiException(statusCode: 401)` |
| `required` | Mandatory; `ApiException(type: auth, 401)` before sending when missing | Refresh once and retry |

For requests to other hosts (signed storage URLs, third-party APIs) use the transport directly
(`netKitManager.transport`, a `RawHttpClient`), which never sends the access token and never
refreshes. `NetKitManager` itself blocks other origins by default (`allowCrossOriginRequests`).

Net-Kit is **not** an HTTP cache layer (RFC 9111).

### Refresh Token Initialization

To use the refresh token feature, you need to initialize the NetKitManager with the following parameters:

| Parameter                        | Required | Description                                                                |
|----------------------------------|----------|----------------------------------------------------------------------------|
| `refreshTokenPath`               | ✅        | Endpoint to request a new access token using the refresh token.            |
| `onTokenRefreshed`               | ✅        | Callback triggered after tokens are successfully refreshed.                |
| `refreshTokenBodyKey`            | ➖        | Key for the refresh token in the refresh body (default: "refreshToken").   |
| `accessTokenBodyKey`             | ➖        | Key for the access token in the refresh body (default: "accessToken").     |
| `removeAccessTokenBeforeRefresh` | ➖        | Send the refresh request without the access token header (default: true). The stored token is kept. |
| `onSessionInvalidated`           | ➖        | Called once when the refresh endpoint answers 401. The only sign-out signal. |
| `refreshTokenContentType`        | ➖        | `json` (default) or `formUrlEncoded` refresh body.                        |
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

  /// Optional: send the refresh request without the Authorization header.
  /// The stored access token itself is never removed by a refresh.
  removeAccessTokenBeforeRefresh: true,

  /// Optional: override the default prefix "Bearer"
  accessTokenPrefix: 'Token',

  /// Optional: customize refresh request before it is sent
  onBeforeRefreshRequest: (options) {
    options.headers['Custom-Header'] = 'MyValue';
    options.body['client_id'] = 'your_client_id';
    options.body['client_secret'] = 'your_secret';
  },

  /// Only called when the refresh endpoint answers 401.
  onSessionInvalidated: (exception) async {
    await tokenManager.clearTokens();
    // Navigate to login screen
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

  // The refresh credential was rejected (refresh endpoint answered 401).
  // Offline, timeouts, and server errors never reach this callback.
  onSessionInvalidated: (exception) async {
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
