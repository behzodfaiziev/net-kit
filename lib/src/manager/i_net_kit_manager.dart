import 'package:dio/dio.dart';

import '../enum/request_method.dart';
import '../model/i_net_kit_model.dart';
import 'params/net_kit_params.dart';

/// The abstract class for the network manager
/// It contains methods to make network requests
abstract class INetKitManager {
  /// The constructor for the INetKitManager class
  const INetKitManager();

  /// The parameters for the network manager
  /// It contains the base options for the network manager
  /// and the parameters for the network manager
  /// The parameters are used to configure the network manager
  /// and the base options are used to configure the network requests
  NetKitParams get parameters;

  /// The base options for the network manager
  /// It contains the base options for the network manager
  BaseOptions get baseOptions;

  /// The `requestModel()` method is responsible for making a network request
  /// to the specified path with the specified method. It takes in the following
  /// parameters:
  /// `path`, `method`, `model`, `body`, `options`, `queryParameters`,
  /// `cancelToken`, and `onReceiveProgress`.
  /// Example:
  /// ```dart
  /// Future<RandomUserModel> getRandomUser() async {
  ///   try {
  ///     final result = await netKitManager.requestModel<RandomUserModel>(
  ///       path: '/api',
  ///       method: RequestMethod.get,
  ///       model: const RandomUserModel(),
  ///     );
  ///     return result;
  ///   }
  ///   /// Catch the ApiException and handle it
  ///   on ApiException catch (e) {
  ///     /// Handle the error: example is to throw the error
  ///     throw Exception(e.message);
  ///   }
  /// }
  /// ```
  ///
  /// The response of the request is returned as a [`RandomUserModel`] object.
  Future<R> requestModel<R extends INetKitModel<R>>({
    required String path,
    required RequestMethod method,

    /// The model to parse the data to
    required R model,
    dynamic body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  });

  /// The `requestList()` method is responsible for making a network request
  /// to the specified path with the specified method. It takes in the following
  /// parameters:
  /// `path`, `method`, `model`, `body`, `options`, `queryParameters`,
  /// `cancelToken`, and `onReceiveProgress`.
  /// Example:
  /// ```dart
  /// Future<List<ProductModel>> getProducts() async {
  ///   try {
  ///     final result = await netKitManager.requestList<ProductModel>(
  ///       path: '/products',
  ///       method: RequestMethod.get,
  ///       model: const ProductModel(),
  ///     );
  ///     return result;
  ///   }
  ///   /// Catch the ApiException and handle it
  ///   on ApiException catch (e) {
  ///     /// Handle the error: example is to throw the error
  ///     throw Exception(e.message);
  ///   }
  /// }
  /// ```

  /// The response of the request is returned
  /// as a [`List<ProductModel>`] object.
  Future<List<R>> requestList<R extends INetKitModel<R>>({
    required String path,
    required RequestMethod method,

    /// The model to parse the data to
    required R model,
    dynamic body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  });

  /// The `requestVoid()` method is responsible for making a network request
  /// to the specified path with the specified method. It takes in the following
  /// parameters:
  /// `path`, `method`, `body`, `options`, `queryParameters`,
  /// `cancelToken`, and `onReceiveProgress`.
  /// Example:
  /// ```dart
  /// Future<void> deleteProduct() async {
  ///   try {
  ///     await netKitManager.requestVoid(
  ///       path: '/products',
  ///       method: RequestMethod.delete,
  ///     );
  ///     return;
  ///   }
  ///   /// Catch the ApiException and handle it
  ///   on ApiException catch (e) {
  ///     /// Handle the error: example is to throw the error
  ///     throw Exception(e.message);
  ///   }
  /// }
  /// ```
  ///
  /// The response of the request is returned as a `null` object, because
  /// the request does not return any data.
  Future<void> requestVoid({
    required String path,
    required RequestMethod method,
    dynamic body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  });

  /// Get all headers
  /// It returns a map of all headers
  Map<String, dynamic> getAllHeaders();

  /// Add a header to the network manager
  /// It takes a `MapEntry<String, String>` as a parameter
  /// The header is added to the network manager
  /// Example:
  /// ```dart
  /// netKitManager.addHeader(MapEntry('Authorization', 'Bearer token'));
  /// ```
  void addHeader(MapEntry<String, String> mapEntry);

  /// Add a bearer token to the network manager
  /// It takes a `String` as a parameter
  /// The bearer token is added to the network manager
  /// Example:
  /// ```dart
  /// netKitManager.addBearerToken('YOUR_BEARER_TOKEN');
  /// ```
  void addBearerToken(String token);

  /// Remove the bearer token from the network manager
  /// The bearer token is removed from the network manager
  /// Example:
  /// ```dart
  /// netKitManager.removeBearerToken();
  /// ```
  /// Usecase: when the user logs out or the token expires
  void removeBearerToken();

  /// Clear all headers
  /// All headers are removed from the network manager
  /// Example:
  /// ```dart
  /// netKitManager.clearAllHeaders();
  /// ```
  /// Usecase: when the user logs out or the token expires
  void clearAllHeaders();

  /// Remove a header from the network manager
  /// It takes a `String` as a parameter
  /// The header is removed from the network manager
  /// Example:
  /// ```dart
  /// netKitManager.removeHeader('Authorization');
  /// ```
  ///
  void removeHeader(String key);

  /// Dispose the network manager
  void dispose();
}
