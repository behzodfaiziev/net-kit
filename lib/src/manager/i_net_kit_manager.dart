import 'package:dio/dio.dart';

import '../enum/request_method.dart';
import '../model/i_net_kit_model.dart';
import '../utility/typedef/request_type_def.dart';
import 'params/net_kit_params.dart';

abstract class INetKitManager {
  const INetKitManager();

  NetKitParams get parameters;

  BaseOptions get baseOptions;

  RequestModel<R> requestModel<R extends INetKitModel<R>>({
    required String path,
    required RequestMethod method,

    /// The model to parse the data to
    required R model,
    dynamic body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  });

  RequestList<R> requestList<R extends INetKitModel<R>>({
    required String path,
    required RequestMethod method,

    /// The model to parse the data to
    required R model,
    dynamic body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  });

  RequestVoid requestVoid({
    required String path,
    required RequestMethod method,
    dynamic body,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  });

  Map<String, dynamic> getAllHeaders();

  void addHeader(MapEntry<String, String> mapEntry);

  void addBearerToken(String token);

  void removeBearerToken();

  void clearAllHeader();

  void removeHeader(String key);
}
