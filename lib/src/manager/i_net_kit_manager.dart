import 'package:dio/dio.dart';

import '../enum/request_method.dart';
import '../interface/i_net_kit_model.dart';
import '../utility/typedef/request_type_defs.dart';
import 'params/net_kit_params.dart';

abstract class INetKitManager {
  const INetKitManager();

  NetKitParams get parameters;

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
}
