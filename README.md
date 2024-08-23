# NetKit

NetKit is a Dart package designed to handle HTTP requests and responses efficiently.

![netkit](https://github.com/user-attachments/assets/f7143f30-6b62-439d-a847-f0fbbf5d3750)

## **Contents**

- [Inspiration](#inspiration)
- [Features](#features)
- [Getting started](#getting-started)
    - [Initialization](#initialization)
- [Sending requests](#sending-requests)
    - [Request a Single Model](#request-a-single-model)
    - [Request a List of Models](#request-a-list-of-models)
    - [Send a Void Request](#send-a-void-request)
- [Planned Enhancements](#planned-enhancements)
- [Contributing](#contributing)
- [License](#license)

## **Inspiration**

NetKit was inspired by the popular [Vexana](https://pub.dev/packages/vexana) package
by [VB10](https://github.com/VB10)

## **Features**

- Supports various HTTP methods (GET, POST, PUT, DELETE, PATCH)
- Configurable base URLs for development and production
- Logging of network requests and responses
- Error handling and response validation
- Parsing responses into models or lists of models or void using `INetKitModel`

## Getting started

### **Initialization**

Initialize the NetKitManager with the parameters:

```dart
import 'package:net_kit/net_kit.dart';

final netKitManager = NetKitManager(
  baseUrl: 'https://api.<URL>.com',
  devBaseUrl: 'https://dev.<URL>.com',
  loggerEnabled: true,
  testMode: true,
  errorStatusCodeKey: 'status',
  errorMessageKey: 'description',
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
    await netKitManager.requestVoid<ProductModel>(
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

## Planned Enhancements
- [x] Internationalization support for error messages
- [ ] No internet connection handling
- [ ] Multi-part form data support
- [ ] Refresh Token implementation
- [ ] Enhance logging capabilities with customizable log levels
- [ ] Provide more examples and use cases in the documentation
- [ ] Implement retry logic for failed requests
- [ ] Add more tests to ensure the package is robust and reliable


## Contributing

Contributions are welcome! Please open an [issue](https://github.com/behzodfaiziev/net-kit/issues) or submit a [pull request](https://github.com/behzodfaiziev/net-kit/pulls).

## License

This project is licensed under the MIT License.
  
