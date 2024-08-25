import 'dart:async';

import 'package:dio/dio.dart';

import '../../enum/log_level.dart';

/// Network kit params for the network manager
class NetKitParams {
  /// The constructor for the NetKitParams class
  const NetKitParams({
    required this.baseOptions,
    required this.testMode,
    required this.loggerEnabled,
    required this.logLevel,
    this.interceptor,
    this.internetStatusSubscription,
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

  /// Whether the network manager is in test mode
  final bool testMode;

  /// Whether the Dio logger is enabled
  final bool loggerEnabled;

  /// The log level for the logger
  final LogLevel logLevel;

  /// Whether the NetKit logger is enabled
  bool get isNetKitLoggerEnabled => logLevel != LogLevel.off;
}
