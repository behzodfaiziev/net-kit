part of '../net_kit_manager.dart';

/// Upload helpers: every upload is a replayable body sent through the same
/// pipeline as JSON requests, so token refresh and retry apply unchanged.
mixin UploadManagerMixin on RequestManagerMixin, ErrorHandlingMixin {
  Converter get _converter;

  Future<R> _upload<R extends INetKitModel>({
    required String path,
    required R model,
    required RawHttpBody body,
    required RequestMethod method,
    required String? contentType,
    required Map<String, String>? headers,
    required Map<String, dynamic>? queryParameters,
    required NetKitTimeout? timeout,
    required NetKitCancellationToken? cancellationToken,
    required NetKitProgressCallback? onSendProgress,
    required NetKitProgressCallback? onReceiveProgress,
    required AuthPolicy authPolicy,
    required bool allowRetryOn401,
    required bool useDataKey,
  }) {
    return _execute(
      _Call(
        path: path,
        method: method.name.toUpperCase(),
        body: body,
        contentType: contentType,
        headers: headers,
        queryParameters: queryParameters,
        timeout: timeout,
        cancellationToken: cancellationToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        authPolicy: authPolicy,
        allowRetryOn401: allowRetryOn401,
      ),
      (outcome) {
        if (model is VoidModel) {
          return model;
        }
        return _decodeModel(outcome, model, useDataKey: useDataKey);
      },
    );
  }

  /// Decodes a JSON object response into [model], honouring `dataKey`.
  R _decodeModel<R extends INetKitModel>(
    _Outcome outcome,
    R model, {
    required bool useDataKey,
  }) {
    if (_hasEmptyResponseBody(outcome)) {
      throw _emptyResponseBodyError(outcome);
    }
    final data = _unwrapData(outcome.data, useDataKey: useDataKey);
    if (data is! MapType) {
      throw _notMapTypeError();
    }
    return _converter.toModel<R>(data, model);
  }

  Object? _unwrapData(Object? data, {required bool useDataKey}) {
    final dataKey = parameters.dataKey;
    if (!useDataKey || dataKey == null) {
      return data;
    }
    if (data is! MapType) {
      throw _notMapTypeError();
    }
    return data[dataKey];
  }
}
