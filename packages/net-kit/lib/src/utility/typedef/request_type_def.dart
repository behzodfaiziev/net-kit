import '../../../net_kit.dart';

/// The map type definition
typedef MapType = Map<String, dynamic>;

/// The request type definition
typedef NetKitRequestFn = Future<Map<String, dynamic>> Function({
  required String path,
  Map<String, dynamic>? body,
  Map<String, String>? headers,
});

/// The request type definition
typedef RefreshTokenRequestBuilder = Future<AuthTokenModel> Function({
  required String refreshTokenPath,
  required String refreshToken,
  required NetKitRequestFn sendRequest,
});
