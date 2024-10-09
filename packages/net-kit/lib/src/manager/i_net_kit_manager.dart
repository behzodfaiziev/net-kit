import 'package:dio/dio.dart';

import '../enum/request_method.dart';
import '../model/i_net_kit_model.dart';
import '../utility/typedef/request_type_def.dart';
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
  Future<R> requestModel<R extends INetKitModel>({
    required String path,
    required RequestMethod method,

    /// The model to parse the data to
    required R model,

    /// The body of the request, which is type of [Map<String, dynamic>]
    MapType? body,
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
  Future<List<R>> requestList<R extends INetKitModel>({
    required String path,
    required RequestMethod method,

    /// The model to parse the data to
    required R model,
    MapType? body,
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
    MapType? body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  });
  /// Signs in a user with their credentials.
  /// 
  /// This method sends a request to the server to authenticate the user 
  /// with their username and password. On successful authentication, it
  /// returns the user model and authentication tokens (access and refresh tokens).
  ///
  /// Example:
  /// ```dart
  /// final result = await netKitManager.signIn<UserModel>(
  ///   path: '/auth/signin',
  ///   method: RequestMethod.post,
  ///   model: UserModel(),
  ///   body: {'username': username, 'password': password},
  /// );
  /// ```
    Future<(R, AuthTokenModel)> signIn<R extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    MapType? body,
    Options? options,
    String accessTokenKey = 'Authorization',
    String refreshTokenKey = 'Refresh-Token'
  });

  /// Signs up a new user with their registration details.
  ///
  /// This method sends a request to the server to register a new user
  /// with the provided details. Upon successful registration, it returns 
  /// the user model and authentication tokens.
  ///
  /// Example:
  /// ```dart
  /// final result = await netKitManager.signUp<UserModel>(
  ///   path: '/auth/signup',
  ///   method: RequestMethod.post,
  ///   model: UserModel(),
  ///   body: {'username': username, 'password': password, 'email': email},
  /// );
  /// ```
  Future<(R, AuthTokenModel)> signUp<R extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    MapType? body,
    Options? options,
    String accessTokenKey = 'Authorization',
    String refreshTokenKey = 'Refresh-Token'
  });
  /// Signs in a user with their social account (e.g., Google, Facebook).
  ///
  /// This method sends a request to the server to authenticate the user
  /// using a social login provider. Instead of username and password, 
  /// it requires the social access token obtained from the provider.
  ///
  /// The server will validate the social access token and, upon successful
  /// authentication, return the user model and authentication tokens.
  ///
  /// Example:
  /// ```dart
  /// final result = await netKitManager.signInWithSocial<UserModel>(
  ///   path: '/auth/social-login',
  ///   method: RequestMethod.post,
  ///   model: UserModel(),
  ///   socialAccessToken: googleAccessToken,  // The token from the social provider
  /// );
  /// ```
  Future<(R, AuthTokenModel)> signInWithSocial<R extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    String socialAccessToken,
    Options? options,
    String accessTokenKey = 'Authorization',
    String refreshTokenKey = 'Refresh-Token',
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
  void addBearerToken(String? token);

  void addRefreshToken(String? token);

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
