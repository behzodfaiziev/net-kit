![h)](https://github.com/user-attachments/assets/d8115ef2-4783-4d2d-88de-df57df40112f)

![Version](https://img.shields.io/pub/v/net_kit)
![License](https://img.shields.io/badge/license-MIT-green)
![Contributions welcome](https://img.shields.io/badge/contributions-welcome-orange)
![GitHub Sponsors](https://img.shields.io/badge/sponsors-welcome-yellow)

### Sponsors

#### A big thanks to our awesome sponsors for keeping this project going!️ Want to help out? Consider becoming a [sponsor](https://github.com/sponsors/behzodfaiziev/)!

<img src="https://github.com/user-attachments/assets/d3463ab8-f7fa-4d75-8595-9335e59a9cad" alt="Jurnalle" width="200px">

## **Contents**

- [Features](#features)
- [Getting started](#getting-started)
    - [Initialize](#initialize)
    - [Extend the model](#extend-the-model)
- [Sending requests](#sending-requests)
    - [Request a Single Model](#request-a-single-model)
    - [Request a List of Models](#request-a-list-of-models)
    - [Send a Void Request](#send-a-void-request)
- [Planned Enhancements](#planned-enhancements)
- [Contributing](#contributing)
- [License](#license)

## **Features**

- 📝 Supports various HTTP methods (GET, POST, PUT, DELETE, PATCH)
- 🌐 Configurable base URLs for development and production
- 📊 Logging of network requests and responses
- ❗ Error handling and response validation
- 🛠 Parsing responses into models or lists of models using `INetKitModel`

## **Getting started**

### **Initialize**

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

### **Extend the model**

Requests such as: `requestModel` and`requestList` require the model to
extend `INetKitModel` in order to be used with the NetKitManager. By extending, `INetKitModel`
`fromJson` and `toJson` methods will be needed to be implemented, so the model can be serialized and
deserialized.

```dart
class TodoModel extends INetKitModel {}
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

[//]: # (## **Best Practices**)

[//]: # (#### **Extend the model**)

## Planned Enhancements

| Feature                                                     | Status |
|:------------------------------------------------------------|:------:|
| Internationalization support for error messages             |   ✅    |
| No internet connection handling                             |   ✅    |
| Provide basic example                                       |   ✅    |
| Provide more examples and use cases in the documentation    |        |
| Multi-part form data support                                |        |
| Refresh Token implementation                                |        |
| Enhance logging capabilities with customizable log levels   |        |
| Implement retry logic for failed requests                   |        |
| Add more tests to ensure the package is robust and reliable |        |
| Add Migration Guide for breaking changes                    |        |

## Contributing

Contributions are welcome! Please open an [issue](https://github.com/behzodfaiziev/net-kit/issues)
or submit a [pull request](https://github.com/behzodfaiziev/net-kit/pulls).

## License

This project is licensed under the MIT License.
  
