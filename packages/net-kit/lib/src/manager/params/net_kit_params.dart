import 'dart:async';

import 'package:dio/dio.dart';

import 'refresh_token_params.dart';

/// Network kit params for the network manager
class NetKitParams {
  /// The constructor for the NetKitParams class
  const NetKitParams({
    required this.baseOptions,
    required this.testMode,
    required this.logInterceptorEnabled,
    required this.accessTokenHeaderKey,
    required this.refreshTokenBodyKey,
    required this.accessTokenBodyKey,
    required this.refreshToken,
    this.interceptor,
    this.internetStatusSubscription,
    this.dataKey,
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

  /// The refresh token parameters
  final RefreshTokenParams refreshToken;

  /// Whether the network manager is in test mode
  final bool testMode;

  /// Whether the network manager logs the network requests
  final bool logInterceptorEnabled;

  /// The access token key.
  /// The default value is ['Authorization']
  /// The access token key can used to get the access token from the headers
  /// of the network responses
  final String accessTokenHeaderKey;

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

  /// The key to extract data from the response.
  /// If null, the response data will be used as is.
  final String? dataKey;
}
