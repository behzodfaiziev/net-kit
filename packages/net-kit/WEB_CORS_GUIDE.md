# Flutter Web CORS Support Guide

This guide explains how to handle Cross-Origin Resource Sharing (CORS) issues when using NetKit with
Flutter Web applications.

## Understanding CORS

CORS is a security feature implemented by web browsers that blocks requests from one domain to
another unless the server explicitly allows it. This affects Flutter Web applications when making
requests to third-party APIs.

## Common CORS Issues

When calling third-party APIs from Flutter Web, you might encounter:

`DioException [connection error]: The connection errored: The XMLHttpRequest onError callback was called`
- `ApiException` with status code 400 and "The XMLHttpRequest onError callback was called. This
  typically indicates an error on the network layer. This indicates an error which most likely
  cannot be solved by the library"
- Requests work in browser navigation but fail in XHR requests

## Solutions

### 1. Configure NetKit for Web (Recommended)

When creating your NetKitManager for web, configure it properly:

```dart
import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/manager/adapter/web_http_adapter.dart';

// For third-party APIs (most common case)
final netKitManager = NetKitManager(
  baseUrl: 'https://api.example.com',
  httpAdapter: const WebHttpAdapter(withCredentials: false), // Default
);

// For your own API with credentials
final netKitManager = NetKitManager(
  baseUrl: 'https://your-api.com',
  httpAdapter: const WebHttpAdapter(withCredentials: true),
);
```

### 2. Server-Side CORS Configuration

If you control the API server, configure it to allow CORS requests:

#### Node.js/Express

```javascript
const cors = require('cors');

app.use(cors({
  origin: ['http://localhost:3000', 'https://yourdomain.com'],
  credentials: false, // Set to true if using withCredentials: true
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

### 3. Using a CORS Proxy (Development Only)

For development with third-party APIs that don't support CORS:

```dart

final netKitManager = NetKitManager(
  baseUrl: 'https://cors-anywhere.herokuapp.com/https://api.example.com',
  // Note: This is for development only, not production
);
```

### 4. Custom Web Adapter Configuration

For advanced CORS handling:

```dart
import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

class CustomWebHttpAdapter implements IHttpAdapter {
  @override
  HttpClientAdapter getAdapter() {
    final adapter = HttpClientAdapter() as BrowserHttpClientAdapter
      ..withCredentials = false // Disable credentials for better compatibility
      ..validateCertificate = false; // Only for development
    return adapter;
  }
}

// Use in NetKitManager
final netKitManager = NetKitManager(
  baseUrl: 'https://api.example.com',
  httpAdapter: CustomWebHttpAdapter(),
);
```

## Best Practices

### 1. Use Appropriate Credentials Setting

```dart
// For public APIs (most third-party APIs)
const WebHttpAdapter
(withCredentials: false)

// For your own authenticated APIs
const WebHttpAdapter(withCredentials: true)
```

### 2. Handle CORS Errors Gracefully

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

### 4. Use Browser Developer Tools

Check the Network tab in browser dev tools to see:

- Preflight OPTIONS requests
- CORS error messages
- Response headers

## Troubleshooting

### Common Error Messages

1. **"XMLHttpRequest onError callback was called"**
    - Usually indicates CORS blocking
    - Check if API supports CORS
    - Try disabling credentials

2. **"Access to XMLHttpRequest has been blocked by CORS policy"**
    - Server doesn't allow your origin
    - Check server CORS configuration

3. **"Response to preflight request doesn't pass access control check"**
    - Server doesn't handle OPTIONS requests properly
    - Check server CORS headers

### Debug Steps

1. **Check Network Tab**: Look for failed requests and CORS errors
2. **Test in Browser**: Try the same URL in a new tab
3. **Check Headers**: Verify CORS headers in response
4. **Test with curl**: `curl -H "Origin: http://localhost:3000" https://api.example.com/data`

## Production Considerations

### 1. Never Use CORS Proxies in Production

CORS proxy services are not suitable for production due to:

- Security risks
- Performance issues
- Reliability concerns

### 2. Configure Your Own Proxy

If you must use a proxy, set up your own:

```dart
// Your own proxy server
final netKitManager = NetKitManager(
  baseUrl: 'https://your-proxy.com/api',
  // Proxy adds CORS headers to third-party API responses
);
```

### 3. Use Server-Side API Calls

For sensitive operations, make API calls from your server instead of the client:

```dart
// Instead of calling third-party API directly
final response = await netKitManager.requestModel<MyModel>(
    path: '/api/third-party-data', // Your server endpoint
    method: RequestMethod.get,
    model: const MyModel(),
  );
```

## Example: Complete Setup

```dart
import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/manager/adapter/web_http_adapter.dart';

class ApiService {
  late final INetKitManager _netKitManager;

  ApiService() {
    _netKitManager = NetKitManager(
      baseUrl: 'https://api.example.com',
      httpAdapter: const WebHttpAdapter(withCredentials: false),
      logger: MyLogger(),
    );
  }

  Future<MyModel> getData() async {
      return await _netKitManager.requestModel<MyModel>(
        path: '/data',
        method: RequestMethod.get,
        model: const MyModel(),
      );
  }
}
```