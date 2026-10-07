/// How a `NetKitManager` request participates in application authentication.
///
/// The policy decides two things: whether the stored access token is attached
/// to the request, and whether a `401` response may trigger an automatic
/// token refresh followed by one retry.
enum AuthPolicy {
  /// Default. Attach the access token when one is stored and refresh on an
  /// eligible `401`. Requests without a stored token are still sent.
  inherit,

  /// Never attach the access token and never refresh. Use for public
  /// endpoints such as login, registration, or health checks. A `401` is
  /// returned to the caller as an `ApiException` without any refresh.
  none,

  /// The access token is mandatory. The request fails before anything is sent
  /// when no token is stored (`ApiFailureType.auth`), and refreshes on an
  /// eligible `401` like [inherit].
  required,
}
