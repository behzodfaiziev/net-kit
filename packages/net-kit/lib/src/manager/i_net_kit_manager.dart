import '../core/auth_policy.dart';
import '../core/net_kit_cancellation_token.dart';
import '../core/net_kit_progress_callback.dart';
import '../core/net_kit_timeout.dart';
import '../enum/request_method.dart';
import '../model/api_meta_response.dart';
import '../model/i_net_kit_model.dart';
import '../raw/net_kit_transport.dart';
import '../raw/raw_http_body.dart';
import '../utility/typedef/request_type_def.dart';
import 'params/net_kit_params.dart';

/// The abstract class for the network manager
/// It contains methods to make network requests
///
/// Every request method shares these parameters:
///
/// - `path`: relative to `baseUrl`, or an absolute URL. Absolute URLs on
///   another origin are rejected unless `allowCrossOriginRequests` is true,
///   and even then never carry the stored headers or access token.
/// - `headers`: per-request headers merged over the stored headers
///   (case-insensitive override). A `Content-Type` header controls how a
///   `body` map is encoded (JSON by default, form-urlencoded when set so).
/// - `timeout`: per-request timeouts merged over the manager-wide ones.
/// - `cancellationToken`: cancels the request; shared tokens are allowed.
/// - `authPolicy`: see [AuthPolicy].
/// - `allowRetryOn401`: lets POST/PATCH be replayed once after a token
///   refresh (GET, PUT, and DELETE are always replayed).
/// - `idempotencyKey`: sent as the `Idempotency-Key` header when set.
abstract class INetKitManager {
  /// The constructor for the INetKitManager class
  const INetKitManager();

  /// The parameters for the network manager
  NetKitParams get parameters;

  /// The transport this manager sends through.
  ///
  /// The transport has no knowledge of the stored headers or tokens, so it
  /// can be used directly as a `RawHttpClient` for external URLs.
  NetKitTransport get transport;

  /// The `requestModel()` method is responsible for making a network request
  /// to the specified path with the specified method and parsing the JSON
  /// object in the response into [model].
  ///
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
  Future<R> requestModel<R extends INetKitModel>({
    required String path,
    required RequestMethod method,

    /// The model to parse the data to
    required R model,

    /// The body of the request, which is type of [Map<String, dynamic>]
    MapType? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onReceiveProgress,
    NetKitProgressCallback? onSendProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    String? idempotencyKey,

    /// Whether to use the dataKey wrapper for this request.
    /// If false, the response data will be used directly without dataKey
    /// extraction. If true, the dataKey will be used if it's configured.
    /// Note: This parameter has no effect if dataKey is not set in the
    /// NetKitManager configuration. Defaults to true.
    bool useDataKey = true,
  });

  /// The `requestModelMeta()` method is similar to the `requestModel` method,
  /// but it includes additional metadata in the response.
  ///
  /// This metadata can provide extra information about the model returned,
  /// such as request details or other relevant data.
  ///
  /// The method signature and parameters are almost identical, but the
  /// return type is `ApiMetaResponse<R, M>`, which wraps the model along
  /// with the metadata.
  Future<ApiMetaResponse<R, M>>
      requestModelMeta<R extends INetKitModel, M extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    required M metadataModel,
    MapType? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onReceiveProgress,
    NetKitProgressCallback? onSendProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    String? idempotencyKey,
    bool useDataKey = true,
  });

  /// The `requestList()` method is responsible for making a network request
  /// to the specified path with the specified method and parsing the JSON
  /// array in the response into a list of [model].
  ///
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
  Future<List<R>> requestList<R extends INetKitModel>({
    required String path,
    required RequestMethod method,

    /// The model to parse the data to
    required R model,
    MapType? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onReceiveProgress,
    NetKitProgressCallback? onSendProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    String? idempotencyKey,
    bool useDataKey = true,
  });

  /// The `requestListMeta()` method is similar to the `requestList` method,
  /// but it includes additional metadata in the response.
  ///
  /// This metadata can provide extra information about the list of items
  /// returned, such as pagination details or other relevant data.
  Future<ApiMetaResponse<List<R>, M>>
      requestListMeta<R extends INetKitModel, M extends INetKitModel>({
    required String path,
    required RequestMethod method,
    required R model,
    required M metadataModel,
    MapType? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onReceiveProgress,
    NetKitProgressCallback? onSendProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    String? idempotencyKey,
    bool useDataKey = true,
  });

  /// The `requestVoid()` method is responsible for making a network request
  /// to the specified path with the specified method without decoding the
  /// response body. A `204 No Content` response is accepted.
  ///
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
  Future<void> requestVoid({
    required String path,
    required RequestMethod method,
    MapType? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onReceiveProgress,
    NetKitProgressCallback? onSendProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    String? idempotencyKey,
  });

  /// Uploads a single file as a `multipart/form-data` body.
  ///
  /// The file is sent as the part named [fieldName]. Use [uploadFormData]
  /// when the form has several fields or files.
  ///
  /// The part content is streamed from its source on every send, so a retry
  /// after a token refresh sends the full payload again without buffering it.
  ///
  /// ### **If return type is not need then use VoidModel as R**
  Future<R> uploadMultipartData<R extends INetKitModel>({
    required String path,

    /// The model to parse the data to
    required R model,
    required NetKitMultipartFile multipartFile,
    required RequestMethod method,
    String fieldName = 'file',
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onSendProgress,
    NetKitProgressCallback? onReceiveProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    bool useDataKey = true,
  });

  /// Uploads a `multipart/form-data` body with text fields and file parts.
  ///
  /// ### **If return type is not need then use VoidModel as R**
  ///
  /// ## Example:
  /// ```dart
  /// final result = await netKitManager.uploadFormData<UserModel>(
  ///   path: '/upload',
  ///   model: UserModel(),
  ///   formData: NetKitFormData.fromMap({
  ///     'title': 'Report',
  ///     'file': await NetKitMultipartFile.fromPath(filePath),
  ///   }),
  ///   method: RequestMethod.post,
  /// );
  /// ```
  Future<R> uploadFormData<R extends INetKitModel>({
    required String path,
    required R model,
    required NetKitFormData formData,
    required RequestMethod method,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onSendProgress,
    NetKitProgressCallback? onReceiveProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    bool useDataKey = true,
  });

  /// Uploads raw bytes as the request body without multipart encoding.
  ///
  /// Typically used for endpoints that expect a raw binary payload such as
  /// `application/octet-stream`. Works on all platforms including web.
  ///
  /// ### **If return type is not need then use VoidModel as R**
  ///
  /// ## Example:
  /// ```dart
  /// final result = await netKitManager.uploadRawData<UploadResponseModel>(
  ///   path: '/upload/raw',
  ///   model: const UploadResponseModel(),
  ///   data: fileBytes,
  ///   method: RequestMethod.put,
  /// );
  /// ```
  Future<R> uploadRawData<R extends INetKitModel>({
    required String path,
    required R model,
    required List<int> data,
    required RequestMethod method,
    String contentType = 'application/octet-stream',
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onSendProgress,
    NetKitProgressCallback? onReceiveProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    bool useDataKey = true,
  });

  /// Uploads a file from disk as the raw request body without multipart
  /// encoding.
  ///
  /// The file is **streamed** with `File.openRead()`; its size comes from
  /// `File.length()` and is sent as `Content-Length`. Nothing is loaded into
  /// memory as a whole, so a 100 MiB file does not cost 100 MiB of memory.
  /// A retry after an automatic token refresh reopens the file and sends the
  /// full payload again. Not supported on web; throws [UnsupportedError]
  /// when file I/O is unavailable.
  ///
  /// ### **If return type is not need then use VoidModel as R**
  ///
  /// ## Example:
  /// ```dart
  /// final result = await netKitManager.uploadFile<UploadResponseModel>(
  ///   path: '/upload/raw',
  ///   model: const UploadResponseModel(),
  ///   filePath: '/path/to/file.bin',
  ///   method: RequestMethod.put,
  /// );
  /// ```
  Future<R> uploadFile<R extends INetKitModel>({
    required String path,
    required R model,
    required String filePath,
    required RequestMethod method,
    String contentType = 'application/octet-stream',
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    NetKitTimeout? timeout,
    NetKitCancellationToken? cancellationToken,
    NetKitProgressCallback? onSendProgress,
    NetKitProgressCallback? onReceiveProgress,
    AuthPolicy authPolicy = AuthPolicy.inherit,
    bool allowRetryOn401 = false,
    bool useDataKey = true,
  });

  /// Get all headers
  /// It returns the stored headers sent with every same-origin request
  Map<String, String> getAllHeaders();

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
  /// Follows the RFC6750 standard for setting the access token
  /// https://datatracker.ietf.org/doc/html/rfc6750#section-2.1
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
