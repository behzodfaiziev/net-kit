/// Content type for the OAuth refresh token request body.
enum RefreshTokenContentType {
  /// JSON body (default).
  json,

  /// `application/x-www-form-urlencoded` body (RFC 6749).
  formUrlEncoded,
}
