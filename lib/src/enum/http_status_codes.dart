/// Enum for HTTP status codes
enum HttpStatuses {
  /// 200 OK
  ok(200),

  /// 300 Multiple Choices
  multipleChoices(300),

  /// 400 Bad Request
  badRequest(400),

  /// 401 Unauthorized
  unauthorized(401),

  /// 403 Forbidden
  forbidden(403),

  /// 404 Not Found
  notFound(404),

  /// 500 Internal Server Error
  internalServerError(500);

  const HttpStatuses(this.code);

  /// The status code for the HTTP status
  final int code;
}
