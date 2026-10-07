import { API, DOC } from '../knowledge/refs.js';

/**
 * Established net_kit usage patterns.
 *
 * Each pattern names the public symbols it relies on and the documentation
 * that backs it; a test verifies every symbol and resource exists in the
 * generated knowledge, so a pattern cannot silently drift from the API.
 */
export interface Pattern {
  readonly id: string;
  readonly title: string;
  readonly summary: string;
  readonly symbols: readonly string[];
  readonly why: readonly string[];
  readonly security: readonly string[];
  readonly example: string;
  readonly resources: readonly string[];
}

export const PATTERNS: readonly Pattern[] = [
  {
    id: 'authenticated-api-call',
    title: 'Authenticated API call',
    summary:
      'Call your own API through NetKitManager; the stored access token is attached and a stale token is refreshed once.',
    symbols: ['NetKitManager', 'AuthPolicy', 'ApiException', 'INetKitModel'],
    why: [
      'NetKitManager decodes JSON into INetKitModel types and handles dataKey envelopes.',
      'AuthPolicy.inherit (the default) sends the token when one is stored and refreshes on an eligible 401.',
      'AuthPolicy.required fails before sending when no token is stored, instead of sending an anonymous request.',
    ],
    security: [
      'The token is only attached to requests on the baseUrl origin.',
      'GET/PUT/DELETE are retried once after refresh; POST/PATCH only with allowRetryOn401 (pair it with idempotencyKey).',
    ],
    example: `final user = await netKitManager.requestModel<UserModel>(
  path: '/me',
  method: RequestMethod.get,
  model: const UserModel(),
  authPolicy: AuthPolicy.required, // or the default AuthPolicy.inherit
);`,
    resources: [DOC.authPolicy, API.netKitManager, API.authPolicy],
  },
  {
    id: 'public-api-call',
    title: 'Public API call',
    summary:
      'Login, registration, and other public endpoints use AuthPolicy.none: no token is sent and a 401 never triggers a refresh.',
    symbols: ['NetKitManager', 'AuthPolicy'],
    why: [
      'AuthPolicy.none strips the access-token header even if one is stored or passed in headers.',
      'A 401 from a public endpoint is returned to the caller; it never starts a refresh and never ends the session.',
    ],
    security: ['A stale token is never leaked to login or registration endpoints.'],
    example: `final session = await netKitManager.requestModel<SessionModel>(
  path: '/auth/login',
  method: RequestMethod.post,
  model: const SessionModel(),
  body: {'email': email, 'password': password},
  authPolicy: AuthPolicy.none,
);
netKitManager
  ..setAccessToken(session.accessToken)
  ..setRefreshToken(session.refreshToken);`,
    resources: [DOC.authPolicy, DOC.migrationAuthPolicy, API.authPolicy],
  },
  {
    id: 'signed-external-upload',
    title: 'Upload to an external signed URL',
    summary:
      'Get the signed URL from your API with NetKitManager, then stream the file to storage with the transport (RawHttpClient). Two clients, two trust levels.',
    symbols: [
      'NetKitManager',
      'RawHttpClient',
      'RawHttpRequest',
      'FileRawHttpBody',
      'NetKitCancellationToken',
    ],
    why: [
      'The transport sends exactly the headers you pass; it never attaches the access token, never refreshes, never retries.',
      'Every status (403 for an expired signature, 5xx) is returned for you to interpret.',
      'FileRawHttpBody streams from disk and sets Content-Length; nothing is buffered.',
      'The URL is sent byte for byte, so signed query strings stay valid.',
    ],
    security: [
      'Never send the application Authorization header to storage hosts.',
      'Redirects are not followed by default, so headers cannot be forwarded elsewhere silently.',
      'Signed URL signatures are redacted from net_kit logs.',
    ],
    example: `final signed = await netKitManager.requestModel<SignedUploadModel>(
  path: '/uploads/sign',
  method: RequestMethod.post,
  model: const SignedUploadModel(),
  body: {'fileName': 'report.pdf'},
);

final RawHttpClient storage = netKitManager.transport;
final response = await storage.send(
  RawHttpRequest(
    uri: Uri.parse(signed.url),
    method: RawHttpMethod.put,
    headers: signed.headers, // only the signed headers
    body: FileRawHttpBody(filePath),
    cancellationToken: cancellationToken,
    onSendProgress: (sent, total) => progress.value = sent / total,
  ),
);
if (!response.isSuccessful) {
  throw UploadException('Storage answered \${response.statusCode}');
}`,
    resources: [DOC.rawTransport, DOC.rawSecurity, API.rawHttpRequest, API.fileBody],
  },
  {
    id: 'replayable-authenticated-upload',
    title: 'Large upload to your own API',
    summary:
      'uploadFile (raw body) and uploadFormData with NetKitMultipartFile.fromPath (multipart) stream from disk and are re-sent in full if the request is retried after a token refresh.',
    symbols: [
      'NetKitManager',
      'NetKitFormData',
      'NetKitMultipartFile',
      'FileRawHttpBody',
      'ReplayableRawHttpBody',
    ],
    why: [
      'Manager upload bodies are replayable: a retry after refresh reopens the file instead of re-sending a consumed stream.',
      'Memory stays bounded regardless of file size.',
      'For non-file sources, NetKitMultipartFile.fromStream(open, length) takes a factory that returns a fresh stream per attempt.',
    ],
    security: ['The upload carries the access token only because it targets the API origin.'],
    example: `await netKitManager.uploadFile<VoidModel>(
  path: '/documents/42/content',
  model: VoidModel(),
  filePath: file.path,
  method: RequestMethod.put,
  contentType: 'application/pdf',
  cancellationToken: cancellationToken,
  onSendProgress: (sent, total) => progress.value = sent / total,
);

await netKitManager.uploadFormData<VoidModel>(
  path: '/documents',
  model: VoidModel(),
  method: RequestMethod.post,
  formData: NetKitFormData.fromMap({
    'title': 'Report',
    'file': await NetKitMultipartFile.fromPath(file.path, filename: 'report.pdf'),
  }),
  allowRetryOn401: true, // POST: opt in to the post-refresh retry
);`,
    resources: [DOC.largeUploads, API.multipartFile, API.formData],
  },
  {
    id: 'streaming-download',
    title: 'Streaming download',
    summary:
      'Use sendStreamed on the transport for large responses: status and headers first, then a back-pressured body stream.',
    symbols: [
      'RawHttpClient',
      'RawHttpRequest',
      'RawHttpStreamedResponse',
      'NetKitCancellationToken',
    ],
    why: [
      'send() buffers the whole body in bodyBytes; sendStreamed() never holds more than the client socket buffers.',
      'Cancelling the token ends the body stream with a cancellation error and releases the connection.',
    ],
    security: [
      'Prefer a short-lived signed download URL from your API over sending the application token on the raw transport.',
    ],
    example: `final response = await netKitManager.transport.sendStreamed(
  RawHttpRequest(uri: Uri.parse(downloadUrl), method: RawHttpMethod.get),
);
if (!response.isSuccessful) {
  throw DownloadException('Status \${response.statusCode}');
}
await response.body.pipe(File(targetPath).openWrite());`,
    resources: [DOC.streamingResponses, API.streamedResponse],
  },
  {
    id: 'cancellation',
    title: 'Cancellation',
    summary:
      'One NetKitCancellationToken can cancel several requests; cancel() is idempotent and a cancelled token cancels new requests immediately.',
    symbols: ['NetKitCancellationToken', 'ApiFailureType'],
    why: [
      'Manager requests surface cancellation as ApiException(type: ApiFailureType.cancelled).',
      'Raw requests surface it as RawHttpException(type: RawHttpFailureType.cancellation).',
      'A request waiting for a token refresh stops waiting immediately; the shared refresh continues for others.',
    ],
    security: [
      'Completed requests release their binding, so long-lived tokens hold no transport handles.',
    ],
    example: `final token = NetKitCancellationToken();
final future = netKitManager.uploadFile<VoidModel>(
  path: '/videos',
  model: VoidModel(),
  filePath: path,
  method: RequestMethod.put,
  cancellationToken: token,
);
// From the cancel button:
token.cancel();`,
    resources: [DOC.cancellation, API.cancellationToken],
  },
  {
    id: 'token-refresh',
    title: 'Token refresh',
    summary:
      'Configure refreshTokenPath; concurrent 401s share one refresh, each request is retried once, and transient refresh failures keep the session.',
    symbols: ['NetKitManager', 'AuthTokenModel', 'OnTokenRefreshed', 'NetKitRequestOptions'],
    why: [
      'An ordinary 401 only means the access token may be stale; it starts or joins one refresh.',
      'Refresh failures other than a refresh-endpoint 401 reach the caller with their real type and fromRefresh == true.',
      'A refresh result that arrives after the app stored new credentials is discarded.',
    ],
    security: [
      'The refresh request never leaves the API origin, whatever allowCrossOriginRequests, onBeforeRefreshRequest, interceptors, or redirects say.',
      'removeAccessTokenBeforeRefresh only omits the header from the refresh request; the stored token is kept.',
    ],
    example: `final netKitManager = NetKitManager(
  baseUrl: 'https://api.example.com',
  refreshTokenPath: '/auth/refresh',
  onTokenRefreshed: (tokens) => tokenStore.save(tokens),
  onSessionInvalidated: (exception) => authController.signOut(),
);`,
    resources: [DOC.howRefreshWorks, DOC.sessionRules, DOC.refreshOrigin],
  },
  {
    id: 'session-invalidation',
    title: 'Session invalidation',
    summary:
      'Only the refresh endpoint answering HTTP 401 ends the session: net_kit clears the tokens, calls onSessionInvalidated once, and fails waiters with ApiFailureType.sessionInvalidated.',
    symbols: ['OnSessionInvalidated', 'ApiFailureType', 'ApiException'],
    why: [
      'Offline, DNS, TLS, timeouts, 429, 5xx, other 4xx, and malformed refresh responses never end the session.',
      'Ten concurrent requests waiting on a rejected refresh produce one callback and ten identical failures.',
      'After invalidation, further 401s are returned without another refresh until new credentials are stored.',
    ],
    security: ['A network outage can never sign the user out.'],
    example: `NetKitManager(
  baseUrl: 'https://api.example.com',
  refreshTokenPath: '/auth/refresh',
  onSessionInvalidated: (exception) => authController.signOut(),
);

try {
  await repository.load();
} on ApiException catch (error) {
  if (error.type == ApiFailureType.sessionInvalidated) return; // signed out already
  showRetryableError(error); // offline, timeout, server error: session kept
}`,
    resources: [DOC.sessionInvalidation, DOC.sessionRules, DOC.refreshOrigin, API.failureType],
  },
  {
    id: 'cross-origin-request',
    title: 'Requests to another origin',
    summary:
      'NetKitManager is pinned to its baseUrl origin. Call other services through the transport, or a separate NetKitManager configured for that service.',
    symbols: ['NetKitManager', 'RawHttpClient', 'NetKitTransport'],
    why: [
      'Absolute URLs on another origin are rejected by default (crossOriginRequestBlockedError).',
      'With allowCrossOriginRequests: true they are sent without stored headers or the access token, and so are cross-origin redirects.',
      'Interceptors that rewrite a request to another origin are subject to the same rules.',
    ],
    security: ['Credentials stay on the API origin, including across redirects.'],
    example: `final RawHttpClient http = netKitManager.transport;
final response = await http.send(
  RawHttpRequest(
    uri: Uri.parse('https://other.example.org/status'),
    method: RawHttpMethod.get,
  ),
);`,
    resources: [DOC.originPolicy, DOC.rawTransport, API.transport],
  },
];

export function findPattern(id: string): Pattern | undefined {
  const key = id
    .trim()
    .toLowerCase()
    .replace(/[\s_]+/g, '-');
  return PATTERNS.find(
    (pattern) => pattern.id === key || pattern.title.toLowerCase() === id.trim().toLowerCase(),
  );
}
