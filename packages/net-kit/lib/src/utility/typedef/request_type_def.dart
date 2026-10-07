import 'dart:async';

import '../../../net_kit.dart';

/// Map type definition
typedef MapType = Map<String, dynamic>;

/// Request options before refresh callback
typedef OnBeforeRefresh = void Function(NetKitRequestOptions options);

/// Called once when the refresh endpoint answers HTTP `401`, after net_kit
/// has cleared the stored access and refresh tokens.
///
/// This is the only session-termination signal. It is never called for a
/// `401` from an ordinary request, for network, timeout, or TLS failures, or
/// for any other refresh status. [exception] has type
/// `ApiFailureType.sessionInvalidated`. The callback is not awaited; errors
/// it throws (synchronously or from a returned future) are logged and
/// otherwise ignored.
typedef OnSessionInvalidated = FutureOr<void> Function(ApiException exception);

/// Callback for when the access token is updated
typedef OnTokenRefreshed = void Function(AuthTokenModel);
