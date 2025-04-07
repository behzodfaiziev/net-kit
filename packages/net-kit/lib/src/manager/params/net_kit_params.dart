import 'dart:async';

import 'package:dio/dio.dart';

import '../../utility/typedef/request_type_def.dart';

/// Network kit params for the network manager
class NetKitParams {
  /// The constructor for the NetKitParams class
  const NetKitParams({
    required this.baseOptions,
    required this.testMode,
    required this.logInterceptorEnabled,
    required this.accessTokenHeaderKey,
    required this.accessTokenPrefix,
    required this.accessTokenBodyKey,
    required this.removeAccessTokenBeforeRefresh,
    required this.metadataDataKey,
    required this.refreshTokenBodyKey,
    required this.onRefreshFailed,
    required this.onBeforeRefreshRequest,
    required this.onTokenRefreshed,
    required this.dataKey,
    required this.interceptor,
    required this.refreshTokenPath,
    required this.internetStatusSubscription,
  });

  /// The subscription for the internet status
  /// The default value is ['null']
  final StreamSubscription<bool>? internetStatusSubscription;

  /// The interceptor for the network requests
  /// The default value is ['null']
  /// The interceptor is used to intercept the network requests:
  /// - onRequest
  /// - onResponse
  /// - onError
  final Interceptor? interceptor;

  /// The base options for the network manager
  /// It is from the Dio package
  final BaseOptions baseOptions;

  /// The function to be called before the refresh token request
  final OnBeforeRefresh? onBeforeRefreshRequest;

  /// The function to be called when the refresh token request fails
  final OnRefreshFailed? onRefreshFailed;

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
  ///  The callback function is called when the tokens are updated
  ///  after a successful refresh token request.
  ///  The callback function is optional and can
  ///  be set when initializing the network manager.
  final OnTokenRefreshed? onTokenRefreshed;

  /// Whether the network manager is in test mode
  final bool testMode;

  /// Whether the network manager logs the network requests
  final bool logInterceptorEnabled;

  /// The access token key.
  /// The default value is ['Authorization']
  /// The access token key can used to get the access token from the headers
  /// of the network responses
  final String accessTokenHeaderKey;

  /// The access token prefix.
  final String accessTokenPrefix;

  /// The refresh token body key.
  /// The default value is ['refreshToken']
  /// The refresh token body key is used to get the refresh token from the body
  /// to use for automatic token refreshing
  final String refreshTokenBodyKey;

  /// The access token body key.
  /// The default value is ['accessToken']
  /// The access token body key is used to get the access token from the body
  /// to use for automatic token refreshing
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
}
