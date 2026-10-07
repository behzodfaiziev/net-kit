/// Error parameters for the error messages and the parsing keys
class NetKitErrorParams {
  /// Constructor for the error parameters
  /// All parameters are optional and have default values
  const NetKitErrorParams({
    this.messageKey = 'message',
    this.statusCodeKey = 'status',
    this.noInternetError = 'No internet connection',
    this.couldNotParseError = 'Could not parse the error',
    this.jsonNullError = 'Empty error message',
    this.jsonIsEmptyError = 'Empty error message',
    this.notMapTypeError = 'Could not parse the response: Not a Map type',
    this.jsonUnsupportedObjectError = 'Unsupported object',
    this.socketExceptionError = 'Socket exception occurred',
    this.invalidTokenResponseError =
        'Could not parse tokens from refresh response',
    this.nonIdempotentRetryBlockedError =
        '401 after refresh; non-idempotent request not retried',
    this.emptyResponseBodyError = 'Response body is empty',
    this.crossOriginRequestBlockedError =
        'Request to a different origin than baseUrl was blocked',
    this.missingAccessTokenError = 'Access token is required but none is set',
    this.timeoutError = 'The request timed out',
    this.requestCancelledError = 'The request was cancelled',
    this.transportError = 'The request could not be completed',
    this.tooManyRedirectsError = 'Too many redirects',
    this.nonReplayableBodyError =
        'Request body cannot be sent again; use a replayable body',
    this.sessionInvalidatedError = 'The session has expired',
    this.unverifiedRedirectError =
        'The refresh response came from a redirect that could not be verified',
  });

  /// The key to use for error messages
  /// The default value is ['message']
  final String messageKey;

  /// The key to use for error status codes
  /// The default value is ['status']
  final String statusCodeKey;

  /// The error message for the no internet error
  /// The default value is ['No internet connection']
  final String noInternetError;

  /// The error message for the could not parse error
  /// The default value is ['Could not parse the error']
  final String couldNotParseError;

  /// The error message for the null JSON error
  /// The default value is ['Empty error message']
  final String jsonNullError;

  /// The error message for the empty JSON error
  /// The default value is ['Empty error message']
  final String jsonIsEmptyError;

  /// The error message for the not map type error
  /// The default value is ['Could not parse the response: Not a Map type']
  final String notMapTypeError;

  /// The error message for the unsupported object error
  /// The default value is ['Unsupported object']
  final String jsonUnsupportedObjectError;

  /// The error message for connection failures (DNS, socket, TLS).
  /// The default value is ['Socket exception occurred']
  final String socketExceptionError;

  /// The error message when a refresh response is missing a valid access token.
  final String invalidTokenResponseError;

  /// The error message when a non-idempotent request is not retried after 401.
  final String nonIdempotentRetryBlockedError;

  /// The error message when a model/list response has no body.
  final String emptyResponseBodyError;

  /// The error message when a request (or a redirect) targets an absolute URL
  /// on a different origin than `baseUrl` while `allowCrossOriginRequests`
  /// is false, or when `AuthPolicy.required` targets another origin.
  final String crossOriginRequestBlockedError;

  /// The error message when `AuthPolicy.required` is used without a stored
  /// access token.
  final String missingAccessTokenError;

  /// The error message for connect, send, or receive timeouts.
  final String timeoutError;

  /// The error message when the request's cancellation token is cancelled.
  final String requestCancelledError;

  /// The error message for unclassified transport failures.
  final String transportError;

  /// The error message when a redirect chain exceeds the limit.
  final String tooManyRedirectsError;

  /// The error message when a single-shot streamed body would have to be
  /// sent a second time (after a token refresh or on a `307`/`308` redirect).
  final String nonReplayableBodyError;

  /// The error message when the refresh endpoint answers `401` and its body
  /// carries no message.
  final String sessionInvalidatedError;

  /// The error message when the HTTP client followed a redirect for the
  /// refresh request on its own (browsers do this unconditionally), so the
  /// responding origin cannot be verified.
  final String unverifiedRedirectError;
}
