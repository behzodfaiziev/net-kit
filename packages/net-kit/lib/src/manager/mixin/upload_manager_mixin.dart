part of '../net_kit_manager.dart';

/// Mixin for upload manager
mixin UploadManagerMixin on DioMixin {
  /// Overridden parameters getter
  NetKitParams get parameters;

  /// Overridden errorParams getter
  NetKitErrorParams get errorParams;

  /// Overridden internetEnabled getter
  bool get internetEnabled;

  Future<R> _uploadMultipartData<R extends INetKitModel>({
    required String path,

    /// The model to parse the data to
    required R model,
    required MultipartFile formData,
    required RequestMethod method,
    Options? options,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    String? contentType,
  }) async {
    if (!internetEnabled) {
      throw ApiException(
        message: errorParams.noInternetError,
        statusCode: HttpStatuses.serviceUnavailable.code,
      );
    }

    options ??= Options();
    options.headers ??= {}; // Ensure headers is not null
    options.headers!['Content-Type'] = contentType ?? 'multipart/form-data';
    options.method = method.name.toUpperCase(); // Set the request method

    final response = await request<dynamic>(
      path,
      data: formData,
      options: options,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    if (R == VoidModel) {
      return VoidModel() as R;
    }
    if ((response.data is MapType) == false) {
      return Converter.toModel<R>(response.data as MapType, model);
    }

    throw ApiException(
      message: errorParams.notMapTypeError,
      statusCode: response.statusCode,
    );
  }
}
