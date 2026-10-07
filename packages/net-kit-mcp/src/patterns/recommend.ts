import { API, DOC } from '../knowledge/refs.js';

/**
 * Deterministic recommendation of net_kit building blocks from stated
 * requirements. Every conclusion records the rule that produced it, so the
 * client can see exactly why a building block was chosen.
 */

export interface Requirements {
  readonly destination?: 'api' | 'external';
  /** Alias for `destination: 'external'`. */
  readonly externalUrl?: boolean;
  readonly authenticated?: boolean;
  readonly publicEndpoint?: boolean;
  readonly bodySource?: 'none' | 'json' | 'bytes' | 'file' | 'stream' | 'multipart';
  readonly largeRequestBody?: boolean;
  readonly requiresReplay?: boolean;
  readonly httpMethod?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  readonly streamResponse?: boolean;
  readonly needsCancellation?: boolean;
  readonly needsProgress?: boolean;
}

export interface Recommendation {
  readonly client: 'NetKitManager' | 'RawHttpClient (NetKitTransport)';
  readonly call: string;
  readonly authPolicy: string | null;
  readonly requestBody: string | null;
  readonly responseHandling: string;
  readonly options: readonly string[];
  readonly reasoning: readonly { readonly rule: string; readonly conclusion: string }[];
  readonly warnings: readonly string[];
  readonly patterns: readonly string[];
  readonly resources: readonly string[];
}

export function recommend(input: Requirements): Recommendation {
  const reasoning: { rule: string; conclusion: string }[] = [];
  const warnings: string[] = [];
  const options: string[] = [];
  const patterns = new Set<string>();
  const resources = new Set<string>();
  const external = input.destination === 'external' || input.externalUrl === true;
  const method =
    input.httpMethod ??
    (input.bodySource === undefined || input.bodySource === 'none' ? 'GET' : 'POST');
  const source = input.bodySource ?? (input.largeRequestBody === true ? 'file' : 'none');

  if (input.needsCancellation === true) {
    options.push('cancellationToken: NetKitCancellationToken()');
    reasoning.push({
      rule: 'cancellation',
      conclusion: 'Pass a NetKitCancellationToken and call cancel() from the cancel action.',
    });
    patterns.add('cancellation');
    resources.add(API.cancellationToken);
  }

  if (external) {
    reasoning.push({
      rule: 'external-destination',
      conclusion:
        'External URLs go through the transport (RawHttpClient): no application credentials, no refresh, no API envelope, every status returned.',
    });
    resources.add(DOC.rawTransport).add(API.rawHttpRequest);
    if (input.authenticated === true) {
      warnings.push(
        'Do not send the application access token to an external host. Obtain a signed URL (or provider-specific credentials) through an authenticated NetKitManager call, then send only the headers that URL requires.',
      );
      reasoning.push({
        rule: 'external-authenticated',
        conclusion:
          'Split the flow: NetKitManager for the API call that signs, transport for the upload/download.',
      });
      patterns.add('signed-external-upload');
      resources.add(DOC.rawSecurity);
    } else {
      patterns.add('cross-origin-request');
    }

    let body: string | null = null;
    if (source === 'file') {
      body = 'FileRawHttpBody(filePath)';
      reasoning.push({
        rule: 'file-body',
        conclusion: 'FileRawHttpBody streams from disk, sets Content-Length, and can be re-sent.',
      });
      resources.add(API.fileBody);
    } else if (source === 'stream') {
      body =
        input.requiresReplay === true
          ? 'ReplayableRawHttpBody(open: () => openStream(), contentLength: length)'
          : 'StreamRawHttpBody(stream: stream, contentLength: length)';
      reasoning.push({
        rule: 'stream-body',
        conclusion:
          input.requiresReplay === true
            ? 'A replay needs a fresh stream per attempt: use ReplayableRawHttpBody with a stream factory.'
            : 'StreamRawHttpBody is single-shot; the transport never retries, so this is fine unless you plan to re-send.',
      });
      resources.add(input.requiresReplay === true ? API.replayableBody : API.streamBody);
    } else if (source === 'bytes') {
      body = 'BytesRawHttpBody(bytes)';
    } else if (source === 'json') {
      body =
        "StringRawHttpBody(jsonEncode(payload)) with headers: {'Content-Type': 'application/json'}";
    } else if (source === 'multipart') {
      body =
        'NetKitFormData(fields: [...], files: [MapEntry(name, await NetKitMultipartFile.fromPath(path))])';
      resources.add(API.formData);
    }
    if (input.requiresReplay === true) {
      warnings.push(
        'The transport never retries on its own. Re-send the request yourself (with a replayable body) if your protocol needs it.',
      );
    }
    if (input.needsProgress === true) {
      options.push('onSendProgress / onReceiveProgress: (count, total) => ...');
    }
    const streamed = input.streamResponse === true;
    if (streamed) {
      patterns.add('streaming-download');
      resources.add(DOC.streamingResponses).add(API.streamedResponse);
    }
    return {
      client: 'RawHttpClient (NetKitTransport)',
      call: `netKitManager.transport.${streamed ? 'sendStreamed' : 'send'}(RawHttpRequest(uri: ..., method: RawHttpMethod.${method.toLowerCase()}, ...))`,
      authPolicy: null,
      requestBody: body,
      responseHandling: streamed
        ? 'RawHttpStreamedResponse: check isSuccessful, then consume or pipe response.body (back-pressured).'
        : 'RawHttpResponse: check statusCode / isSuccessful; bodyBytes holds the whole body.',
      options,
      reasoning,
      warnings,
      patterns: [...patterns],
      resources: [...resources],
    };
  }

  // Own API.
  resources.add(API.netKitManager);
  let authPolicy = 'AuthPolicy.inherit';
  if (input.publicEndpoint === true || input.authenticated === false) {
    authPolicy = 'AuthPolicy.none';
    reasoning.push({
      rule: 'public-endpoint',
      conclusion: 'AuthPolicy.none: no token is sent and a 401 never triggers a refresh.',
    });
    patterns.add('public-api-call');
  } else {
    reasoning.push({
      rule: 'authenticated-endpoint',
      conclusion:
        'AuthPolicy.inherit (default) attaches the stored token and refreshes once on 401; use AuthPolicy.required to fail fast without a token.',
    });
    patterns.add('authenticated-api-call');
  }
  resources.add(DOC.authPolicy);

  let call =
    'netKitManager.requestModel<T>(path: ..., method: RequestMethod.' +
    method.toLowerCase() +
    ', model: ...)';
  let body: string | null = source === 'json' ? 'body: {...} (JSON-encoded)' : null;
  if (source === 'file') {
    call = `netKitManager.uploadFile<T>(path: ..., model: ..., filePath: path, method: RequestMethod.${method.toLowerCase()})`;
    body = 'File streamed from disk (FileRawHttpBody), reopened for the post-refresh retry.';
    reasoning.push({
      rule: 'file-upload',
      conclusion:
        'uploadFile streams the file and re-sends it in full after a token refresh; memory stays bounded.',
    });
    patterns.add('replayable-authenticated-upload');
    resources.add(DOC.largeUploads);
  } else if (source === 'multipart') {
    call = `netKitManager.uploadFormData<T>(path: ..., model: ..., formData: NetKitFormData.fromMap({...}), method: RequestMethod.${method.toLowerCase()})`;
    body = 'NetKitMultipartFile.fromPath(...) parts are streamed and replayable.';
    patterns.add('replayable-authenticated-upload');
    resources.add(API.multipartFile);
  } else if (source === 'bytes') {
    call = `netKitManager.uploadRawData<T>(path: ..., model: ..., data: bytes, method: RequestMethod.${method.toLowerCase()})`;
    body = 'In-memory bytes (fine for small payloads).';
    if (input.largeRequestBody === true) {
      warnings.push(
        'Large in-memory byte uploads cost their full size in memory; prefer uploadFile or NetKitMultipartFile.fromPath when the data is on disk.',
      );
    }
  } else if (source === 'stream') {
    call = `netKitManager.uploadFormData<T>(... NetKitMultipartFile.fromStream(() => openStream(), length) ...)`;
    body =
      'Stream factory: a fresh stream per attempt, so a post-refresh retry re-sends everything.';
    reasoning.push({
      rule: 'stream-on-manager',
      conclusion: 'NetKitManager only accepts replayable bodies; wrap the source in a factory.',
    });
  }

  if ((method === 'POST' || method === 'PATCH') && authPolicy !== 'AuthPolicy.none') {
    if (input.requiresReplay === true) {
      options.push('allowRetryOn401: true', "idempotencyKey: '<unique key>'");
      reasoning.push({
        rule: 'non-idempotent-retry',
        conclusion:
          'POST/PATCH are not retried after refresh unless allowRetryOn401 is set; add an idempotency key.',
      });
    } else {
      reasoning.push({
        rule: 'non-idempotent-default',
        conclusion:
          'POST/PATCH are not replayed after a refresh by default (RFC 9110); the caller gets ApiFailureType.auth.',
      });
    }
  }
  if (input.needsProgress === true) {
    options.push('onSendProgress / onReceiveProgress: (count, total) => ...');
  }
  if (input.streamResponse === true) {
    warnings.push(
      'NetKitManager decodes whole JSON responses and has no streaming response API. For large downloads, have the API return a short-lived signed download URL and stream it with netKitManager.transport.sendStreamed.',
    );
    patterns.add('streaming-download');
    resources.add(DOC.streamingResponses);
  }
  if (authPolicy !== 'AuthPolicy.none') {
    patterns.add('token-refresh');
    resources.add(DOC.sessionRules);
  }

  return {
    client: 'NetKitManager',
    call,
    authPolicy,
    requestBody: body,
    responseHandling:
      'Decoded into INetKitModel; failures are ApiException with an ApiFailureType.',
    options,
    reasoning,
    warnings,
    patterns: [...patterns],
    resources: [...resources],
  };
}
