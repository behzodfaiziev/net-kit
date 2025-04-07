import '../../../net_kit.dart';

/// Map type definition
typedef MapType = Map<String, dynamic>;

/// Request options before refresh callback
typedef OnBeforeRefresh = void Function(NetKitRequestOptions options);

/// Refresh failed callback
typedef OnRefreshFailed = void Function({
  required int? statusCode,
  required DioException exception,
});

/// Callback for when the access token is updated
typedef OnTokenRefreshed = void Function(AuthTokenModel);
