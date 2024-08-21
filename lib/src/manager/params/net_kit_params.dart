import 'package:dio/dio.dart';

/// Network kit params for the network manager
class NetKitParams {
  /// The constructor for the NetKitParams class
  const NetKitParams({
    required this.baseOptions,
    required this.errorMessageKey,
    required this.errorStatusCodeKey,
    this.interceptor,
    this.testMode = false,
    this.loggerEnabled = false,
  });

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

  /// Whether the network manager is in test mode
  final bool testMode;

  /// Whether the logger is enabled
  final bool loggerEnabled;

  /// The key to use for error messages
  /// while parsing the error response
  final String errorMessageKey;

  /// The key to use for error status
  /// codes while parsing the error response
  final String errorStatusCodeKey;
}
