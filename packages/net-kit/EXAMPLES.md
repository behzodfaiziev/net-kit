# NetKit Examples

This file contains detailed examples and real-world use cases for NetKitManager.

## Table of Contents

- [Service Layer Pattern](#service-layer-pattern)
- [Pagination with Metadata](#pagination)
- [Error Handling Strategies](#error-handling)
- [File Upload Examples](#file-uploads)
- [Advanced Configuration](#advanced-configuration)
- [DataKey Configuration Examples](#datakey-configuration-examples)
- **[Token Management Guide →](https://github.com/behzodfaiziev/net-kit/blob/main/packages/net-kit/TOKEN_MANAGEMENT.md)** - Comprehensive token refresh, storage, and lifecycle management

## Service Layer Pattern

This section demonstrates how to implement NetKitManager with proper separation of concerns.

The service layer pattern is crucial for creating a clean abstraction over NetKit. This pattern
ensures that your application doesn't become directly dependent on NetKit, making it easier to test,
maintain, and potentially switch network libraries in the future.

#### Why Use a Service Layer?

1. **Dependency Inversion**: Your business logic depends on abstractions, not concrete
   implementations
2. **Testability**: Easy to mock the service layer for unit testing
3. **Maintainability**: Changes to NetKit don't affect your business logic
4. **Consistency**: Centralized network configuration and error handling
5. **Flexibility**: Easy to add features like caching, retry logic, or analytics

#### Service Layer Implementation

<details>
<summary>📋 <strong>AppNetworkManager Interface</strong></summary>

```dart
// Core/network/app_network_manager.dart
abstract class AppNetworkManager {
  Future<T> requestModel<T extends AppNetworkModel>(String path, {
    required T parseModel,
    required AppRequestType method,
    MapType? body,
    bool? containsAccessToken,
  });

  Future<List<T>> requestList<T extends AppNetworkModel>(String path, {
    required T parseModel,
    required AppRequestType method,
    MapType? body,
    bool? containsAccessToken,
  });

  Future<PaginatedList<R>> requestPaginatedList<R extends AppNetworkModel>(String path, {
    required R parseModel,
    required AppRequestType method,
    MapType? body,
    bool? containsAccessToken,
  });

  Future<void> requestVoid(String path, {
    required AppRequestType method,
    MapType? body,
    bool? containsAccessToken,
  });

  Future<T> uploadFormData<T extends AppNetworkModel>(String path, {
    required T model,
    required AppRequestType method,
    required AppFormData formData,
  });

  void setToken({required TokenModel token});

  void clearTokens();
}
```

</details>

<details>
<summary>🔧 <strong>AppNetworkManager Implementation</strong></summary>

```dart
// Core/network/app_network_manager_impl.dart
final class AppNetworkManagerImpl implements AppNetworkManager {
  AppNetworkManagerImpl({
    required Stream<ConnectivityResultEnum> internetStatusStream,
    required AuthLocalStorageService authStorage,
  })
      : _internetStatusStream = internetStatusStream,
        _authLocalStorage = authStorage {
    _manager = _initManager();
  }

  late INetKitManager _manager;
  final Stream<ConnectivityResultEnum> _internetStatusStream;
  final AuthLocalStorageService _authLocalStorage;

  NetKitManager _initManager() {
    return NetKitManager(
      baseUrl: APIConst.baseUrl,
      devBaseUrl: APIConst.baseDevUrl,
      testMode: kDebugMode,
      logger: NetworkLogger(),
      internetStatusStream: _internetStatusStream.map(
            (event) => event != ConnectivityResultEnum.none,
      ),
      baseOptions: BaseOptions(headers: {'Content-Type': 'application/json'}),
      refreshTokenPath: APIConst.refreshToken,
      dataKey: 'data',
      onTokenRefreshed: (token) {
        _authLocalStorage.setAccessToken(token.accessToken ?? '');
        if (token.refreshToken != null) {
          _authLocalStorage.setRefreshToken(token.refreshToken!);
        }
      },
      errorParams: const NetKitErrorParams(),
    );
  }

  @override
  Future<T> requestModel<T extends AppNetworkModel>(String path, {
    required T parseModel,
    required AppRequestType method,
    MapType? body,
    bool? containsAccessToken,
  }) async {
    try {
      final result = await _manager.requestModel<T>(
        path: path,
        model: parseModel,
        method: method.toRequestType,
        body: body,
        containsAccessToken: containsAccessToken,
      );
      return result;
    } on ApiException catch (e) {
      throw ServerException.fromApiException(e);
    } catch (e) {
      throw ServerException(message: e.toString(), statusCode: 505);
    }
  }

  @override
  Future<List<T>> requestList<T extends AppNetworkModel>(String path, {
    required T parseModel,
    required AppRequestType method,
    MapType? body,
    bool? containsAccessToken,
  }) async {
    try {
      final result = await _manager.requestList<T>(
        path: path,
        model: parseModel,
        method: method.toRequestType,
        body: body,
        containsAccessToken: containsAccessToken,
      );
      return result;
    } on ApiException catch (e) {
      throw ServerException.fromApiException(e);
    } catch (e) {
      throw ServerException(message: e.toString(), statusCode: 505);
    }
  }

  @override
  Future<PaginatedList<R>> requestPaginatedList<R extends AppNetworkModel>(String path, {
    required R parseModel,
    required AppRequestType method,
    MapType? body,
    bool? containsAccessToken,
  }) async {
    try {
      final result = await _manager.requestListMeta<R, PaginationMetadataModel>(
        path: path,
        model: parseModel,
        metadataModel: const PaginationMetadataModel(),
        method: method.toRequestType,
        body: body,
        containsAccessToken: containsAccessToken,
      );

      final metadata = result.metadata;
      return PaginatedList<R>(
        data: result.data,
        currentPage: metadata.currentPage,
        isLastPage: metadata.isLastPage,
        totalPages: metadata.totalPages,
      );
    } on ApiException catch (e) {
      throw ServerException.fromApiException(e);
    } catch (e) {
      throw ServerException(message: e.toString(), statusCode: 505);
    }
  }

  @override
  Future<void> requestVoid(String path, {
    required AppRequestType method,
    MapType? body,
    bool? containsAccessToken,
  }) async {
    try {
      await _manager.requestVoid(
        path: path,
        method: method.toRequestType,
        body: body,
        containsAccessToken: containsAccessToken,
      );
    } on ApiException catch (e) {
      throw ServerException.fromApiException(e);
    } catch (e) {
      throw ServerException(message: e.toString(), statusCode: 505);
    }
  }

  @override
  Future<T> uploadFormData<T extends AppNetworkModel>(String path, {
    required T model,
    required AppRequestType method,
    required AppFormData formData,
  }) async {
    try {
      return await _manager.uploadFormData<T>(
        path: path,
        model: model,
        formData: formData.form,
        method: method.toRequestType,
      );
    } on ApiException catch (e) {
      throw ServerException.fromApiException(e);
    } catch (e) {
      throw ServerException(message: e.toString(), statusCode: 505);
    }
  }

  @override
  void setToken({required TokenModel token}) {
    _manager
      ..setAccessToken(token.accessToken)
      ..setRefreshToken(token.refreshToken);
  }

  @override
  void clearTokens() {
    _manager
      ..clearAllHeaders()
      ..removeAccessToken()
      ..removeRefreshToken();
    _manager = _recreateManager();
  }

  NetKitManager _recreateManager() {
    _manager.dispose();
    return _initManager();
  }
}
```

</details>

<details>
<summary>🔐 <strong>Business Service Implementation</strong></summary>

```dart
// Features/auth/service/auth_service.dart
abstract class AuthService {
  Future<SignInDto> signIn(SignInRequestDto dto);

  Future<SignInDto> socialSignInWithGoogle(SocialSignInRequestDto dto);

  Future<SignInDto> socialSignInWithApple(SocialSignInRequestDto dto);

  Future<SignUpDto> signUp(SignUpRequestDto dto);

  Future<void> signOut();

  Future<UserModel> getMe();

  void setToken(TokenModel token);

  void clearTokens();
}

// Features/auth/service/auth_service_impl.dart
final class AuthServiceImpl implements AuthService {
  AuthServiceImpl({required AppNetworkManager network}) : _network = network;

  final AppNetworkManager _network;

  @override
  Future<SignInDto> signIn(SignInRequestDto dto) {
    return _network.requestModel<SignInDto>(
      APIConst.signIn,
      method: AppRequestType.post,
      body: dto.toJson(),
      parseModel: const SignInDto(),
    );
  }

  @override
  Future<SignInDto> socialSignInWithGoogle(SocialSignInRequestDto dto) {
    return _network.requestModel<SignInDto>(
      APIConst.socialSignInWithGoogle,
      method: AppRequestType.post,
      body: dto.toJson(),
      parseModel: const SignInDto(),
    );
  }

  @override
  Future<SignInDto> socialSignInWithApple(SocialSignInRequestDto dto) {
    return _network.requestModel<SignInDto>(
      APIConst.socialSignInWithApple,
      method: AppRequestType.post,
      body: dto.toJson(),
      parseModel: const SignInDto(),
    );
  }

  @override
  Future<SignUpDto> signUp(SignUpRequestDto dto) {
    return _network.requestModel<SignUpDto>(
      APIConst.signUp,
      method: AppRequestType.post,
      body: dto.toJson(),
      parseModel: const SignUpDto(),
    );
  }

  @override
  Future<void> signOut() async {
    _network.clearTokens();
    await _network.requestVoid(APIConst.signOut, method: AppRequestType.post);
  }

  @override
  Future<UserModel> getMe() async {
    final result = await _network.requestModel<UserDto>(
      APIConst.userDetails,
      parseModel: const UserDto(),
      method: AppRequestType.get,
    );
    return result.toModel;
  }

  @override
  void setToken(TokenModel token) {
    _network.setToken(token: token);
  }

  @override
  void clearTokens() {
    _network.clearTokens();
  }
}
```

</details>

<details>
<summary>📚 <strong>Repository Implementation with Better Error Messages</strong></summary>

```dart
// Data/repositories/auth_repo_impl.dart
final class AuthRepoImpl implements AuthRepo {
  AuthRepoImpl({
    required AuthService authService,
    required AuthLocalStorageService storageService,
    required SocialSignInService socialSignInService,
  })
      : _authService = authService,
        _socialSignInService = socialSignInService,
        _storageService = storageService;

  final AuthService _authService;
  final AuthLocalStorageService _storageService;
  final SocialSignInService _socialSignInService;

  @override
  ResultFuture<bool> checkIsAuthenticated() async {
    try {
      // Retrieve stored token from local storage (SharedPreferences, Hive, etc.)
      final token = await _storageService.getToken();

      // Check if token exists and has a valid refresh token
      if (token == null || token.refreshToken.isEmpty) {
        return const Right(false); // No valid token found
      }

      // Set the token in the network service for immediate use
      // This ensures the token is available for subsequent API calls
      _authService.setToken(token);

      return const Right(true); // User is authenticated
    } on CacheException catch (e) {
      return Left(CacheFailure.fromException(e));
    }
  }

  @override
  ResultFuture<void> signOut() async {
    try {
      // Remove token from local storage to prevent auto-login
      await _storageService.removeToken();

      // Call server-side sign out to invalidate the token
      await _authService.signOut();

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure.fromException(e));
    } on CacheException catch (e) {
      return Left(CacheFailure.fromException(e));
    }
  }

  @override
  ResultFuture<void> requestForgotPassword(String email) async {
    try {
      // Request password reset from the server
      final result = await _authService.requestForgotPasswordEmail(
        ForgotPasswordEmailRequestDto(email: email),
      );

      // Some APIs return a temporary access token for password reset
      if (result.accessToken == null) {
        return const Left(ServerFailure(
          message: 'Password reset request failed. Please try again later.',
          statusCode: 505,
        ));
      }

      // Set the temporary token for password reset flow
      // Empty refresh token because this is a temporary access token
      _authService.setToken(TokenModel(accessToken: result.accessToken!, refreshToken: ''));

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure.fromException(e));
    } on ValidationException catch (e) {
      return Left(ValidationFailure.fromException(e));
    }
  }

  @override
  ResultFuture<void> signIn(SignInParams params) async {
    try {
      // Send sign-in request to the server
      final result = await _authService.signIn(SignInRequestDto.fromParams(params));

      // Validate that we received a valid access token
      if (result.accessToken == null) {
        return const Left(ServerFailure(
          message: 'Sign in failed. Invalid credentials provided.',
          statusCode: 505,
        ));
      }

      // Create token model with both access and refresh tokens
      final token = TokenModel(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken ?? '', // Use empty string if no refresh token
      );

      // Set token in the network service for immediate API calls
      _authService.setToken(token);

      // Persist token to local storage for future app launches
      // This enables auto-login functionality
      await _storageService.setToken(token);

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure.fromException(e));
    }
  }

  @override
  ResultFuture<void> signInWithGoogle() async {
    try {
      // Get Google access token from Google Sign-In SDK
      final accessToken = await _socialSignInService.signInWithGoogle();

      // Send Google token to our backend for verification and user creation/login
      final result = await _authService.socialSignInWithGoogle(
          SocialSignInRequestDto(token: accessToken));

      // Validate server response
      if (result.accessToken == null) {
        return const Left(ServerFailure(
          message: 'Google sign in failed. Please try again.',
          statusCode: 505,
        ));
      }

      // Create our app's token from the server response
      final token = TokenModel(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken ?? '',
      );

      // Set token for immediate use in API calls
      _authService.setToken(token);

      // Save token for future app sessions
      await _storageService.setToken(token);

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure.fromException(e));
    } on Exception catch (e) {
      return Left(ServerFailure(
        message: 'Google sign in failed: ${e.toString()}',
        statusCode: 505,
      ));
    }
  }

  @override
  ResultFuture<void> signInWithApple() async {
    try {
      // Get Apple ID token from Apple Sign-In SDK
      final accessToken = await _socialSignInService.signInWithApple();

      // Send Apple token to our backend for verification
      final result = await _authService.socialSignInWithApple(
          SocialSignInRequestDto(token: accessToken));

      // Validate server response
      if (result.accessToken == null) {
        return const Left(ServerFailure(
          message: 'Apple sign in failed. Please try again.',
          statusCode: 505,
        ));
      }

      // Create our app's token from the server response
      final token = TokenModel(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken ?? '',
      );

      // Set token for immediate use in API calls
      _authService.setToken(token);

      // Save token for future app sessions
      await _storageService.setToken(token);

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure.fromException(e));
    } on Exception catch (e) {
      return Left(ServerFailure(
        message: 'Apple sign in failed: ${e.toString()}',
        statusCode: 505,
      ));
    }
  }

  @override
  ResultFuture<void> signUp(SignUpParams params) async {
    try {
      // Send sign-up request to the server
      final result = await _authService.signUp(SignUpRequestDto.fromParams(params));

      // Validate that account was created successfully
      if (result.accessToken == null) {
        return const Left(ServerFailure(
          message: 'Sign up failed. Please check your information and try again.',
          statusCode: 505,
        ));
      }

      // Create token model (sign-up typically doesn't provide refresh token initially)
      final token = TokenModel(accessToken: result.accessToken!, refreshToken: '');

      // Set token for immediate use
      _authService.setToken(token);

      // Save token for future app sessions
      await _storageService.setToken(token);

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure.fromException(e));
    } on ValidationException catch (e) {
      return Left(ValidationFailure.fromException(e));
    }
  }
}
```

</details>

#### Benefits of This Approach

1. **Clean Separation**: Business logic is completely separated from network implementation
2. **Easy Testing**: Mock `AppNetworkManager` instead of NetKit directly
3. **Consistent Error Handling**: All network errors are handled in one place
4. **Centralized Configuration**: All NetKit configuration is in one place
5. **Type Safety**: Custom types ensure compile-time safety
6. **Easy Maintenance**: Changes to NetKit only affect the service layer

## Pagination

The `requestListMeta` method is perfect for implementing pagination. Here's a complete example:

<details>
<summary>📊 <strong>Pagination Models</strong></summary>

```dart
class PaginationMetadataModel extends INetKitModel {
  const PaginationMetadataModel({
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalItems = 0,
    this.limit = 10,
    this.isLastPage = true,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int limit;
  final bool isLastPage;

  @override
  PaginationMetadataModel fromJson(Map<String, dynamic> json) {
    return PaginationMetadataModel(
      currentPage: json['currentPage'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 1,
      totalItems: json['totalItems'] as int? ?? 0,
      limit: json['limit'] as int? ?? 10,
      isLastPage: json['isLastPage'] as bool? ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'currentPage': currentPage,
      'totalPages': totalPages,
      'totalItems': totalItems,
      'limit': limit,
      'isLastPage': isLastPage,
    };
  }
}

class PaginatedList<T> extends Equatable {
  const PaginatedList({
    required this.data,
    required this.currentPage,
    required this.isLastPage,
    this.totalPages,
    this.filters,
  });

  final List<T> data;
  final int currentPage;
  final bool isLastPage;
  final int? totalPages;
  final Map<String, dynamic>? filters;

  @override
  List<Object?> get props => [data, currentPage, isLastPage, totalPages, filters];

  PaginatedList<M> convertToModel<M>(M Function(T) converter) {
    return PaginatedList<M>(
      data: data.map(converter).toList(),
      currentPage: currentPage,
      isLastPage: isLastPage,
      totalPages: totalPages,
      filters: filters,
    );
  }
}
```

</details>

<details>
<summary>⚙️ <strong>Pagination Service Implementation</strong></summary>

```dart
class AppNetworkManagerImpl {
  final NetKitManager _manager;

  AppNetworkManagerImpl(this._manager);

  @override
  Future<PaginatedList<R>> requestPaginatedList<R extends INetKitModel>(String path, {
    required R parseModel,
    required RequestMethod method,
    MapType? body,
    bool? containsAccessToken,
  }) async {
    try {
      final result = await _manager.requestListMeta<R, PaginationMetadataModel>(
        path: path,
        model: parseModel,
        metadataModel: const PaginationMetadataModel(),
        method: method,
        body: body,
        containsAccessToken: containsAccessToken,
      );

      // Extract pagination metadata from the response
      final metadata = result.metadata;
      final currentPage = metadata.currentPage;
      final totalPages = metadata.totalPages;
      final isLastPage = metadata.isLastPage;

      return PaginatedList<R>(
        data: result.data,
        currentPage: currentPage,
        isLastPage: isLastPage,
        totalPages: totalPages,
      );
    } on ApiException catch (e) {
      throw ServerException.fromApiException(e);
    } catch (e) {
      throw ServerException(message: e.toString(), statusCode: 505);
    }
  }
}
```

</details>

## File Uploads

<details>
<summary>📦 <strong>Wrapper Pattern for Package Independence</strong></summary>

Use wrapper classes to keep your code independent from the underlying HTTP package:

```dart
// AppMultipartFile wraps MultipartFile for independence
class AppMultipartFile {
  AppMultipartFile(this.file);

  final MultipartFile file;
}

// AppFormData wraps FormData for independence  
class AppFormData {
  AppFormData(this.form);

  final FormData form;
}

// AppMedia represents file data in a package-agnostic way
class AppMedia {
  final String path;
  final String? filename;
  final String? mimeType;

  const AppMedia({
    required this.path,
    this.filename,
    this.mimeType,
  });
}
```

**Benefits of this approach:**

- **Package Independence**: Easy to switch HTTP libraries without changing business logic
- **Clean Architecture**: Business logic doesn't depend on specific HTTP implementations
- **Testability**: Easy to mock and test without HTTP dependencies
- **Consistency**: Uniform interface across all file operations

</details>

<details>
<summary>📤 <strong>Multipart File Upload with Form Data</strong></summary>

```dart
// Example: Upload user profile with multiple documents
Future<void> uploadUserProfile({
  required String name,
  required String email,
  required AppMedia profileImage,
  required AppMedia identityDocument,
}) async {
  try {
    // Create multipart files using the service layer (keeps code independent)
    final profileImageFile = await _authService.createMultipartFile(
      media: profileImage,
    );

    final identityDocFile = await _authService.createMultipartFile(
      media: identityDocument,
    );

    // Create user data DTO
    final userData = UserProfileDto(
      name: name,
      email: email,
      platform: Platform.isAndroid ? 'ANDROID' : 'IOS',
    );

    // Create form data with mixed content (JSON + files)
    final formMap = <String, dynamic>{
      'userData': jsonEncode(userData.toJson()), // JSON data
      'profileImage': profileImageFile.file, // File upload
      'identityDocument': identityDocFile.file, // File upload
    };

    // Create form data using the service layer
    final AppFormData formData = _authService.createFormDataFromMap(map: formMap);

    // Upload using NetKitManager
    await netKitManager.uploadFormData<void>(
      path: '/user/profile/upload',
      method: RequestMethod.post,
      formData: formData.form, // Access the underlying FormData
    );

    print('Profile uploaded successfully');
  } on ApiException catch (e) {
    throw UploadException('Failed to upload profile: ${e.message}');
  }
}
```

</details>

<details>
<summary>📁 <strong>Single File Upload with Progress</strong></summary>

```dart
// Example: Upload a single image with progress tracking
Future<UploadResponseModel> uploadImage(AppMedia imageMedia, {
  String? description,
  ProgressCallback? onProgress,
}) async {
  try {
    // Create multipart file using the service layer
    final appMultipartFile = await _authService.createMultipartFile(
      media: imageMedia,
    );

    final result = await netKitManager.uploadMultipartData<UploadResponseModel>(
      path: '/upload/image',
      method: RequestMethod.post,
      model: const UploadResponseModel(),
      multipartFile: appMultipartFile.file,
      // Access the underlying MultipartFile
      onSendProgress: onProgress, // Track upload progress
    );

    return result;
  } on ApiException catch (e) {
    throw UploadException('Failed to upload image: ${e.message}');
  }
}
```

</details>

<details>
<summary>📋 <strong>Form Data with Mixed Content</strong></summary>

```dart
// Example: Submit form with text fields and file uploads
Future<FormSubmissionResponse> submitApplication({
  required String fullName,
  required String email,
  required String phone,
  required AppMedia resume,
  required AppMedia coverLetter,
  Map<String, dynamic>? additionalInfo,
}) async {
  try {
    // Create multipart files using the service layer
    final resumeFile = await _authService.createMultipartFile(
      media: resume,
    );

    final coverLetterFile = await _authService.createMultipartFile(
      media: coverLetter,
    );

    // Create application data
    final applicationData = ApplicationDto(
      fullName: fullName,
      email: email,
      phone: phone,
      additionalInfo: additionalInfo,
    );

    // Create form data with mixed content
    final formMap = <String, dynamic>{
      'applicationData': jsonEncode(applicationData.toJson()), // JSON
      'resume': resumeFile.file, // File
      'coverLetter': coverLetterFile.file, // File
      'timestamp': DateTime.now().toIso8601String(), // Simple field
    };

    // Create form data using the service layer
    final AppFormData appFormData = _authService.createFormDataFromMap(map: formMap);

    final result = await netKitManager.uploadFormData<FormSubmissionResponse>(
      path: '/applications/submit',
      method: RequestMethod.post,
      model: const FormSubmissionResponse(),
      formData: appFormData.form, // Access the underlying FormData
    );

    return result;
  } on ApiException catch (e) {
    throw FormSubmissionException('Failed to submit application: ${e.message}');
  }
}
```

## Error Handling

NetKitManager handles errors automatically through its built-in error handling system. You don't need to implement
custom error handlers as the library provides comprehensive error management out of the box.

### Built-in Error Handling Features

- **Automatic Exception Conversion**: Converts HTTP errors to `ApiException` with proper status codes
- **Token Refresh**: Automatically handles token refresh when access tokens expire
- **Network Status**: Monitors internet connectivity and handles offline scenarios


## Advanced Configuration

<details>
<summary>📝 <strong>Custom Logger Implementation</strong></summary>

```dart
class CustomLogger implements INetKitLogger {
  @override
  void debug(String message) {
    if (kDebugMode) {
      print('🐛 DEBUG: $message');
    }
  }

  @override
  void error(String message) {
    print('❌ ERROR: $message');
    // Send to crash reporting service
  }

  @override
  void info(String message) {
    print('ℹ️ INFO: $message');
  }

  @override
  void warning(String message) {
    print('⚠️ WARNING: $message');
  }
}

// Usage
final netKitManager = NetKitManager(
  baseUrl: 'https://api.example.com',
  logger: CustomLogger(),
  loggerEnabled: true,
);
```

</details>

## DataKey Configuration Examples

<details>
<summary>🔑 <strong>Mixed API Response Formats</strong></summary>

```dart
// API that returns data wrapped from 'data' key
final user = await netKitManager.requestModel<UserModel>(
    path: '/user/profile', 
    method: RequestMethod.get,
    model: const UserModel(),
    useDataKey: true, // Uses configured dataKey
  );

// API that returns data directly
final settings = await netKitManager.requestModel<SettingsModel>(
  path: '/user/settings',
  method: RequestMethod.get,
  model: const SettingsModel(),
  useDataKey: false, // Ignores dataKey, uses response.data directly
);
```

</details>

This examples file provides comprehensive guidance for implementing various features with
NetKitManager, from basic usage to advanced scenarios.
