import 'package:dio/dio.dart';

import '../enum/request_method.dart';
import '../model/auth_token_model.dart';
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

  /// General authentication method that handles
  /// sign-in, sign-up, and social login.
  ///
  /// This method can be used for:
  /// - **Sign In**: Authenticate users
  /// with their credentials (username, password).
  /// - **Sign Up**: Register new users
  /// with their details (username, password, email, etc.).
  /// - **Social Login**: Authenticate users
  /// with social media access tokens (e.g., Google, Facebook).
  ///
  /// Parameters:
  /// - [path]: The API endpoint for the request.
  /// - [method]: The HTTP request method (POST, GET, etc.).
  /// - [model]: The model to parse the response.
  /// - [body]: The request body, typically
  /// containing credentials or user details.
  /// - [options]: Optional Dio request options.
  /// - [socialAccessToken]: Optional access token for social login.
  /// - [accessTokenKey]: The key for accessing
  /// the authorization token in headers.
  /// - [refreshTokenKey]: The key for accessing the refresh token in headers.
  ///
  /// Example for Sign In:
  /// ```dart
  /// final result = await netKitManager.authenticate<UserModel>(
  ///   path: '/auth/signin',
  ///   method: RequestMethod.post,
  ///   model: UserModel(),
  ///   body: {'username': username, 'password': password},
  /// );
  /// final user = result.$1;
  /// final authToken = result.$2;
  /// ```
  ///
  /// Example for Sign Up:
  /// ```dart
  /// final result = await netKitManager.authenticate<UserModel>(
  ///   path: '/auth/signup',
  ///   method: RequestMethod.post,
  ///   model: UserModel(),
  ///   body: {'username': username, 'password': password, 'email': email},
  /// );
  /// final user = result.$1;
  /// final authToken = result.$2;
  /// ```
  ///
  /// Example for Social Login:
  /// ```dart
  /// final result = await netKitManager.authenticate<UserModel>(
  ///   path: '/auth/social-login',
  ///   method: RequestMethod.post,
  ///   model: UserModel(),
  ///   socialAccessToken: googleAccessToken,
  /// );
  /// final user = result.$1;
  /// final authToken = result.$2;
  /// ```
  Future<(R, AuthTokenModel)> authenticate<R extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    MapType? body,
    Options? options,
    String? socialAccessToken,
  });

  /// This method is responsible for uploading multipart form data to a
  /// specified endpoint. Typically used for uploading files or other
  /// data where multipart encoding is required.
  ///
  /// R extends INetKitModel: The generic type R must extend the INetKitModel.
  /// This allows the server response to be parsed into a specific model
  /// class that represents the data returned by the API.
  ///
  /// ### **If return type is not need then use VoidModel as R**
  Future<R> uploadMultipartData<R extends INetKitModel>({
    required String path,

    /// The model to parse the data to
    required R model,
    required MultipartFile multipartFile,
    required RequestMethod method,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,

    /// The content type of the file. Defaults to `application/form-data`.
    String? contentType,
  });

  /// This method is responsible for uploading form data to
  /// a specified endpoint. Typically used for submitting forms or
  /// other data where multipart encoding is required.
  ///
  /// R extends INetKitModel: The generic type R must extend the INetKitModel.
  /// This allows the server response to be parsed into a specific model class
  /// that represents the data returned by the API.
  ///
  /// ### **If return type is not need then use VoidModel as R**
  /// ## Returns:
  /// - A Future that resolves to an instance of R, which extends INetKitModel.
  ///
  /// ## Example:
  /// ```dart
  /// final result = await netKitManager.uploadFormData<UserModel>(
  ///   path: '/upload',
  ///   model: UserModel(),
  ///   formData: formData,
  ///   method: RequestMethod.post,
  /// );
  /// ```
  Future<R> uploadFormData<R extends INetKitModel>({
    required String path,
    required R model,
    required FormData formData,
    required RequestMethod method,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,

    /// The content type of the file. Defaults to `application/form-data`.
    String? contentType,
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

  /// Set an access token to the network manager
  /// It takes a `String` as a parameter
  /// The access token is added to the network manager
  /// Example:
  /// ```dart
  /// netKitManager.setAccessToken('YOUR_ACCESS_TOKEN');
  /// ```
  void setAccessToken(String? token);

  /// Set a refresh token to the network manager
  /// It takes a `String` as a parameter
  /// The refresh token is added to the network manager
  /// Example:
  /// ```dart
  /// netKitManager.setRefreshToken('YOUR_REFRESH_TOKEN');
  /// ```
  /// Usecase: when the user logs in
  /// and the refresh token is received
  void setRefreshToken(String? token);

  /// Remove the refresh token from the network manager
  /// The refresh token is removed from the network manager
  /// Example:
  /// ```dart
  /// netKitManager.removeRefreshToken();
  /// ```
  /// Usecase: when the user logs out or the token expires
  void removeRefreshToken();

  /// Remove access token from the network manager
  /// The access token is removed from the network manager
  /// Example:
  /// ```dart
  /// netKitManager.removeBearerToken();
  /// ```
  /// Usecase: when the user logs out or the token expires
  void removeAccessToken();

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
