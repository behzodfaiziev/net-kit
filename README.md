# NetKit

![netkit](https://github.com/user-attachments/assets/eb34c4cf-80d5-43aa-823d-7f578f90663b)
NetKit is a Dart package designed to handle HTTP requests and responses efficiently.

## **Inspiration**

NetKit was inspired by the popular [Vexana](https://pub.dev/packages/vexana) package
by [VB10](https://github.com/VB10).

## **Features**

- Supports various HTTP methods (GET, POST, PUT, DELETE, PACTH)
- Configurable base URLs for development and production
- Logging of network requests and responses
- Error handling and response validation
- Parsing responses into models or lists of models or void using `INetKitModel`

## Getting started

### **Initialization**

Initialize the NetKitManager with the parameters:

```dart

final netKitManager = NetKitManager(
  baseUrl: 'https://api.<URL>.com',
  devBaseUrl: 'https://dev.<URL>.com',
  loggerEnabled: true,
  testMode: true,
  errorStatusCodeKey: 'status',
  errorMessageKey: 'description',
);
```

### **Sending requests**

#### **Requesting a Single Model**

```dart

final response = await netKitManager.requestModel<BookModel>(
    path: '/book/1',
    method: RequestMethod.get,
    model: BookModel(),
  );

  response.fold(
    (error) => print('Error: ${error.description}'),
    (book) => print('Book: $book'), // book type is BookModel
  );
```

#### **Requesting a List of Models**

```dart

final response = await netKitManager.requestList(
    path: '/books',
    method: RequestMethod.get,
    model: BookModel(),
  );

  response.fold(
    (error) => print('Error: ${error.description}'),
    (books) => print('Books: $books'), // books type is List<BookModel>
  );
```

#### **Sending a Void Request**

```dart

final response = await netKitManager.requestVoid(
    path: '/book/1',
    method: RequestMethod.DELETE,
  );

  response.fold(
    (error) => print('Error: ${error.description}'),
    (result) => print('Book deleted successfully'), // result type is void 
);
```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License.
  
