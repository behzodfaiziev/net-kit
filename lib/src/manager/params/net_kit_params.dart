import 'package:dio/dio.dart';

class NetKitParams {
  const NetKitParams({
    required this.interceptor,
    required this.baseOptions,
    this.testMode = false,
    this.bypassSSLCertificate = false,
    this.loggerEnabled = false,
  });

  final Interceptor interceptor;

  final BaseOptions baseOptions;

  final bool testMode;

  final bool bypassSSLCertificate;

  final bool loggerEnabled;
}
