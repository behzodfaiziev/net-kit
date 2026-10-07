import 'dart:async';

import '../manager/error/api_exception.dart';
import '../raw/raw_http_request.dart';
import '../raw/raw_http_response.dart';

/// Application hook into every `NetKitManager` request.
///
/// Interceptors run after net_kit has resolved the absolute URL, merged
/// headers, and applied the request's `AuthPolicy`, and before the request
/// reaches the transport. They see the final [RawHttpRequest] and the raw
/// transport response. Each hook may return the value unchanged or a
/// replacement. Hooks run in registration order for requests and responses.
///
/// Auth injection, token refresh, origin checks, and error mapping are
/// performed by `NetKitManager` itself; interceptors observe their result.
abstract class NetKitInterceptor {
  /// Allows subclasses to have `const` constructors.
  const NetKitInterceptor();

  /// Called before each transport send, including retries and redirects.
  FutureOr<RawHttpRequest> onRequest(RawHttpRequest request) => request;

  /// Called with each transport response before status handling.
  FutureOr<RawHttpResponse> onResponse(
    RawHttpRequest request,
    RawHttpResponse response,
  ) =>
      response;

  /// Called once with the [ApiException] a request is about to throw.
  ///
  /// [request] is `null` when the failure happened before a transport
  /// request was built (for example when offline or when a required access
  /// token is missing). Return the same or a replacement exception.
  FutureOr<ApiException> onError(RawHttpRequest? request, ApiException error) =>
      error;
}
