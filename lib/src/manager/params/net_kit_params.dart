import 'package:dio/dio.dart';

class NetKitParams {
  const NetKitParams({
    required this.baseOptions,
    required this.errorMessageKey,
    required this.errorStatusCodeKey,
    this.interceptor,
    this.testMode = false,
    this.loggerEnabled = false,
  });

  final Interceptor? interceptor;

  final BaseOptions baseOptions;

  final bool testMode;

  final bool loggerEnabled;

  final String errorMessageKey;

  final String errorStatusCodeKey;
}
