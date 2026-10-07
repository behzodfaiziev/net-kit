import 'dart:async';

import '../../core/net_kit_interceptor.dart';
import '../../core/net_kit_timeout.dart';
import '../../enum/refresh_token_content_type.dart';
import '../../utility/typedef/request_type_def.dart';

/// Network kit params for the network manager
class NetKitParams {
  /// The constructor for the NetKitParams class
  const NetKitParams({
    required this.baseUrl,
    required this.headers,
    required this.timeout,
    required this.devMode,
    required this.accessTokenHeaderKey,
    required this.accessTokenPrefix,
    required this.accessTokenBodyKey,
    required this.removeAccessTokenBeforeRefresh,
    required this.metadataDataKey,
    required this.refreshTokenBodyKey,
    required this.onSessionInvalidated,
    required this.onBeforeRefreshRequest,
    required this.onTokenRefreshed,
    required this.dataKey,
    required this.interceptors,
    required this.refreshTokenPath,
    required this.internetStatusSubscription,
    required this.allowCrossOriginRequests,
    required this.sensitiveHeaders,
    required this.logResponseBodies,
    required this.sensitiveQueryParameters,
    this.refreshTokenContentType = RefreshTokenContentType.json,
  });

  /// The effective base URL: `devBaseUrl` in dev mode, otherwise `baseUrl`.
  final String baseUrl;

  /// Headers sent with every same-origin request. Mutable: `setAccessToken`,
  /// `addHeader`, and friends edit this map.
  final Map<String, String> headers;

  /// Manager-wide timeouts, merged under per-request timeouts.
  final NetKitTimeout timeout;

  /// The subscription for the internet status
  /// The default value is ['null']
  final StreamSubscription<bool>? internetStatusSubscription;

  /// Interceptors in execution order. Includes the development log
  /// interceptor when it is enabled.
  final List<NetKitInterceptor> interceptors;

  /// The function to be called before the refresh token request
  final OnBeforeRefresh? onBeforeRefreshRequest;

  /// Called once when the refresh endpoint answers `401` and the session is
  /// over. See [OnSessionInvalidated].
  final OnSessionInvalidated? onSessionInvalidated;

  /// The callback function that is called when the tokens are updated
  /// This function can be used to update the tokens in the app
  /// or perform any other actions that are required when the tokens are updated
  /// The callback function is optional and can be
  /// set when initializing the network manager
  /// Example:
  /// ```dart
  /// final netKitManager = NetKitManager(
  ///  baseUrl: 'https://api.example.com',
  ///  onTokenRefreshed: (authToken) {
  ///  // Update the tokens in the app
  ///   },
  ///  );
  ///  ```
  ///  The callback function takes an [`AuthTokenModel`] as a parameter
  ///  which contains the access token and refresh token.
  final OnTokenRefreshed? onTokenRefreshed;

  /// Whether the network manager is in development mode.
  final bool devMode;

  /// The access token key.
  /// The default value is ['Authorization']
  final String accessTokenHeaderKey;

  /// The access token prefix.
  final String accessTokenPrefix;

  /// The refresh token body key.
  /// The default value is ['refreshToken']
  final String refreshTokenBodyKey;

  /// The access token body key.
  /// The default value is ['accessToken']
  final String accessTokenBodyKey;

  /// The path for the refresh token request
  final String? refreshTokenPath;

  /// Whether to remove the access token header before refreshing the token
  final bool removeAccessTokenBeforeRefresh;

  /// The key to extract data from the response.
  /// If null, the response data will be used as is.
  final String? dataKey;

  /// The key to extract data from the metadata response.
  final String metadataDataKey;

  /// Content type for the refresh token request body.
  final RefreshTokenContentType refreshTokenContentType;

  /// Whether absolute URLs on another origin than [baseUrl] may be requested.
  /// Such requests never carry [headers].
  final bool allowCrossOriginRequests;

  /// Lower-case header names treated as credentials: redacted from logs and
  /// stripped when a redirect leaves the request's origin.
  final Set<String> sensitiveHeaders;

  /// Lower-case query parameter names whose values are redacted from logged
  /// URLs.
  final Set<String> sensitiveQueryParameters;

  /// Whether parsed response data is written to the injected logger and the
  /// development log interceptor prints bodies.
  final bool logResponseBodies;
}
