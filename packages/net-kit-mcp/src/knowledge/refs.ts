/**
 * Documentation and API resources cited by analyzer findings and patterns.
 * A test verifies every URI here resolves against the generated knowledge.
 */
export const DOC = {
  architecture: 'netkit://docs/readme.architecture',
  authPolicy: 'netkit://docs/readme.auth-policy-per-request',
  sessionInvalidation: 'netkit://docs/readme.session-invalidation',
  sessionRules: 'netkit://docs/auth.when-the-session-ends-and-when-it-does-not',
  refreshOrigin: 'netkit://docs/auth.refresh-request-origin',
  howRefreshWorks: 'netkit://docs/auth.how-token-refresh-works',
  rawTransport: 'netkit://docs/readme.raw-http-transport',
  rawSecurity: 'netkit://docs/readme.security-model',
  cancellation: 'netkit://docs/readme.methods-cancellation-and-progress',
  largeUploads: 'netkit://docs/readme.large-file-uploads',
  streamingResponses: 'netkit://docs/readme.streaming-responses',
  originPolicy: 'netkit://docs/readme.origin-and-redirect-policy',
  interceptors: 'netkit://docs/readme.interceptors',
  logging: 'netkit://docs/readme.logger-integration',
  migrationLedger: 'netkit://docs/migration.breaking-change-ledger',
  migrationChecklist: 'netkit://docs/migration.checklist',
  migrationAuthPolicy: 'netkit://docs/migration.auth-policy',
  migrationSession: 'netkit://docs/migration.session-invalidation-replaces-onrefreshfailed',
  migrationConstructor: 'netkit://docs/migration.constructor',
  migrationRequest: 'netkit://docs/migration.request',
  migrationMultipart: 'netkit://docs/migration.multipart-upload',
  migrationInterceptor: 'netkit://docs/migration.interceptor',
  migrationRawClient: 'netkit://docs/migration.raw-client',
  migrationErrors: 'netkit://docs/migration.errors',
} as const;

export const API = {
  netKitManager: 'netkit://api/NetKitManager',
  authPolicy: 'netkit://api/AuthPolicy',
  transport: 'netkit://api/NetKitTransport',
  rawHttpClient: 'netkit://api/RawHttpClient',
  rawHttpRequest: 'netkit://api/RawHttpRequest',
  fileBody: 'netkit://api/FileRawHttpBody',
  replayableBody: 'netkit://api/ReplayableRawHttpBody',
  streamBody: 'netkit://api/StreamRawHttpBody',
  streamedResponse: 'netkit://api/RawHttpStreamedResponse',
  cancellationToken: 'netkit://api/NetKitCancellationToken',
  multipartFile: 'netkit://api/NetKitMultipartFile',
  formData: 'netkit://api/NetKitFormData',
  failureType: 'netkit://api/ApiFailureType',
  logInterceptor: 'netkit://api/RedactingLogInterceptor',
  interceptor: 'netkit://api/NetKitInterceptor',
  timeout: 'netkit://api/NetKitTimeout',
} as const;
