import { API, DOC } from '../../knowledge/refs.js';
import { enclosingBlocks, identifiers, namedArg, type CallSite, type DartFile } from '../model.js';
import type { Finding, Rule } from '../types.js';
import { callRange, callText, finding, managerConstructions, UPLOAD_METHODS } from './helpers.js';

/** Variables in [file] assigned from `readAsBytes()` / `readAsBytesSync()`. */
function bytesVariables(file: DartFile): Set<string> {
  const names = new Set<string>();
  for (const call of file.calls) {
    if (call.name !== 'readAsBytes' && call.name !== 'readAsBytesSync') continue;
    // Walk back to `name =` within the statement.
    for (let i = call.index - 1; i >= 0; i--) {
      const text = file.tokens[i]?.text;
      if (text === ';' || text === '{' || text === '}') break;
      if (text === '=' && file.tokens[i - 1]?.kind === 'ident') {
        names.add(file.tokens[i - 1]?.text ?? '');
        break;
      }
    }
  }
  return names;
}

function readsWholeFile(
  file: DartFile,
  call: CallSite,
  argName: string | null,
  variables: Set<string>,
): boolean {
  const arg = argName === null ? call.args.find((a) => a.name === null) : namedArg(call, argName);
  if (arg === undefined) return false;
  const names = identifiers(arg.tokens);
  return (
    names.includes('readAsBytes') ||
    names.includes('readAsBytesSync') ||
    names.some((n) => variables.has(n))
  );
}

/** NK004: a file read into memory before uploading. */
export const nk004: Rule = {
  id: 'NK004',
  title: 'File read fully into memory for an upload',
  categories: ['upload', 'streaming'],
  description:
    'readAsBytes() materializes the whole file. net_kit can stream files from disk and reopen them for a retry after token refresh.',
  run({ files }) {
    const out: Finding[] = [];
    for (const file of files) {
      const variables = bytesVariables(file);
      for (const call of file.calls) {
        let target: {
          arg: string | null;
          replacement: string;
          confidence: 'high' | 'medium';
          resources: string[];
        } | null = null;
        if (call.isMember && call.name === 'uploadRawData') {
          target = {
            arg: 'data',
            confidence: 'high',
            replacement:
              'netKitManager.uploadFile(path: ..., model: ..., filePath: file.path, method: ..., contentType: ...)',
            resources: [DOC.largeUploads, API.netKitManager],
          };
        } else if (call.name === 'BytesRawHttpBody' && !call.isMember) {
          target = {
            arg: null,
            confidence: 'high',
            replacement: 'FileRawHttpBody(file.path)',
            resources: [DOC.largeUploads, API.fileBody],
          };
        } else if (call.name === 'fromBytes' && call.qualifier === 'NetKitMultipartFile') {
          target = {
            arg: null,
            confidence: 'medium',
            replacement:
              'await NetKitMultipartFile.fromPath(file.path, filename: ..., contentType: ...)',
            resources: [DOC.largeUploads, API.multipartFile],
          };
        }
        if (target === null || !readsWholeFile(file, call, target.arg, variables)) continue;
        out.push(
          finding(file, {
            ruleId: 'NK004',
            title: this.title,
            severity: 'warning',
            confidence: target.confidence,
            range: callRange(call),
            message:
              'This upload reads the whole file into memory first (readAsBytes). Peak memory grows with the file size, and the bytes stay referenced until the request (and any retry) finishes.',
            recommendation:
              'Stream from disk instead. net_kit reopens file bodies for the retry after a token refresh, so streaming does not lose replayability.',
            resources: target.resources,
            suggestion: {
              currentPattern: callText(file, call),
              suggestedPattern: target.replacement,
              explanation:
                'File-backed bodies use File.openRead() per attempt and send Content-Length from File.length(); nothing is buffered.',
            },
          }),
        );
      }
    }
    return out;
  },
};

const CANCEL_HINT =
  /\b(cancelUpload|onCancel|CancelButton|cancelButton|isCancel\w*|abortUpload|stopUpload)\b|\bcancel\s*\(/;

/** NK008: file upload without cancellation in code that offers cancel. */
export const nk008: Rule = {
  id: 'NK008',
  title: 'Upload without a cancellation token',
  categories: ['upload'],
  description:
    'Long uploads behind a cancel action should pass a NetKitCancellationToken so cancelling stops the transfer instead of only hiding it.',
  run({ files }) {
    const out: Finding[] = [];
    for (const file of files) {
      if (!CANCEL_HINT.test(file.text)) continue;
      for (const call of file.calls) {
        // In-memory byte uploads (uploadRawData) are usually small; only
        // file- and stream-backed uploads are long enough to need cancelling.
        const isManagerUpload =
          call.isMember && UPLOAD_METHODS.has(call.name) && call.name !== 'uploadRawData';
        const isRawFileUpload =
          call.name === 'RawHttpRequest' &&
          !call.isMember &&
          /FileRawHttpBody|ReplayableRawHttpBody|StreamRawHttpBody/.test(
            namedArg(call, 'body')?.text ?? '',
          );
        if (!isManagerUpload && !isRawFileUpload) continue;
        if (namedArg(call, 'cancellationToken') !== undefined) continue;
        out.push(
          finding(file, {
            ruleId: 'NK008',
            title: this.title,
            severity: 'info',
            confidence: 'low',
            range: callRange(call),
            message:
              'This upload has no cancellationToken, while the surrounding code appears to offer cancelling. Cancelling the UI would not stop the transfer.',
            recommendation:
              'Create a NetKitCancellationToken per upload, pass it as cancellationToken, and call cancel() from the cancel action.',
            resources: [DOC.cancellation, API.cancellationToken],
          }),
        );
      }
    }
    return out;
  },
};

/** NK013: single-shot stream body built from a file. */
export const nk013: Rule = {
  id: 'NK013',
  title: 'Single-shot stream body where a replayable body fits',
  categories: ['upload', 'streaming'],
  description:
    'StreamRawHttpBody can be sent once. For files, FileRawHttpBody (or ReplayableRawHttpBody) can be reopened per attempt and computes the length for you.',
  run({ files }) {
    const out: Finding[] = [];
    for (const file of files) {
      for (const call of file.calls) {
        if (call.name !== 'StreamRawHttpBody' || call.isMember) continue;
        const stream = namedArg(call, 'stream');
        if (stream === undefined || !identifiers(stream.tokens).includes('openRead')) continue;
        const inLoop = enclosingBlocks(file, call.index).some((b) =>
          /^(for|while|do)\b|\bretry\w*\b/i.test(b.header.map((t) => t.text).join(' ')),
        );
        out.push(
          finding(file, {
            ruleId: 'NK013',
            title: this.title,
            severity: inLoop ? 'warning' : 'info',
            confidence: inLoop ? 'medium' : 'high',
            range: callRange(call),
            message: inLoop
              ? 'A single-shot StreamRawHttpBody built from File.openRead() appears inside a retry loop; a second attempt cannot re-send a consumed stream.'
              : 'This StreamRawHttpBody streams a file once. A FileRawHttpBody does the same, can be re-sent, and reads the length from the file.',
            recommendation:
              'Use FileRawHttpBody(path), or ReplayableRawHttpBody(open: ..., contentLength: ...) for non-file sources.',
            resources: [DOC.largeUploads, API.fileBody, API.replayableBody],
            suggestion: {
              currentPattern: callText(file, call),
              suggestedPattern: 'FileRawHttpBody(file.path)',
              explanation:
                'Replayable bodies are opened again for each attempt; nothing is buffered.',
            },
          }),
        );
      }
    }
    return out;
  },
};

const DOWNLOAD_HINT =
  /\b(download\w*|writeAsBytes\w*|saveTo\w*|\w*Video\w*|\w*Archive\w*|\w*Backup\w*|\w*Export\w*)\b/;

/** NK010: buffered raw response used for what looks like a large download. */
export const nk010: Rule = {
  id: 'NK010',
  title: 'Large download buffered in memory',
  categories: ['streaming'],
  description:
    'NetKitTransport.send buffers the entire body in bodyBytes. sendStreamed delivers status and headers first and streams the body with back-pressure.',
  run({ files }) {
    const out: Finding[] = [];
    for (const file of files) {
      if (!/\bRawHttpRequest\b|\bRawHttpClient\b|\bNetKitTransport\b|\.transport\b/.test(file.text))
        continue;
      for (const call of file.calls) {
        if (!call.isMember || call.name !== 'send') continue;
        const arg = call.args[0];
        if (arg === undefined || !/RawHttpRequest|request/i.test(arg.text)) continue;
        const scope = enclosingBlocks(file, call.index)[0];
        if (scope === undefined) continue;
        const body = file.tokens.slice(scope.open, scope.close + 1);
        const text = body.map((t) => t.text).join(' ');
        const header = scope.header.map((t) => t.text).join(' ');
        if (!/\bbodyBytes\b/.test(text)) continue;
        if (!DOWNLOAD_HINT.test(`${header} ${text}`)) continue;
        out.push(
          finding(file, {
            ruleId: 'NK010',
            title: this.title,
            severity: 'warning',
            confidence: /writeAsBytes/.test(text) ? 'high' : 'medium',
            range: callRange(call),
            message:
              'This appears to download a potentially large body with send(), which holds the whole response in memory (bodyBytes) before it is written anywhere.',
            recommendation:
              'Use sendStreamed() and pipe response.body to its destination (for example a file sink); check response.isSuccessful first and cancel with a NetKitCancellationToken if needed.',
            resources: [DOC.streamingResponses, API.streamedResponse],
            suggestion: {
              currentPattern: callText(file, call),
              suggestedPattern: [
                'final response = await client.sendStreamed(request);',
                'if (!response.isSuccessful) { /* handle status */ }',
                'await response.body.pipe(File(targetPath).openWrite());',
              ].join('\n'),
              explanation: 'The body stream honours back-pressure, so memory stays bounded.',
            },
          }),
        );
      }
    }
    return out;
  },
};

/** NK012: body logging without a sanitizer in an authenticated setup. */
export const nk012: Rule = {
  id: 'NK012',
  title: 'Body logging enabled without a sanitizer',
  categories: ['configuration', 'auth'],
  description:
    'Bodies of login and refresh exchanges contain tokens. Body logging is off by default; when enabled, a bodySanitizer should mask secrets.',
  run({ files, facts }) {
    const out: Finding[] = [];
    for (const file of files) {
      for (const call of managerConstructions(file)) {
        if (namedArg(call, 'logResponseBodies')?.text !== 'true') continue;
        const inert =
          namedArg(call, 'devMode')?.text === 'false' || namedArg(call, 'devMode') === undefined;
        out.push(
          finding(file, {
            ruleId: 'NK012',
            title: this.title,
            severity: inert ? 'info' : 'warning',
            confidence: inert ? 'low' : facts.usesRefresh ? 'high' : 'medium',
            range: callRange(call),
            message: inert
              ? 'logResponseBodies is enabled, but devMode is not set here, so logging stays inert. If devMode is enabled elsewhere, bodies (including token responses) will be logged unmasked.'
              : 'logResponseBodies prints request and response bodies, including login and refresh payloads that carry tokens, through the built-in log interceptor without masking.',
            recommendation:
              'Keep logResponseBodies off, or register RedactingLogInterceptor(logBodies: true, bodySanitizer: mask) in interceptors instead.',
            resources: [DOC.logging, API.logInterceptor],
          }),
        );
      }
      for (const call of file.calls) {
        if (call.name !== 'RedactingLogInterceptor' || call.isMember) continue;
        if (namedArg(call, 'logBodies')?.text !== 'true') continue;
        if (namedArg(call, 'bodySanitizer') !== undefined) continue;
        out.push(
          finding(file, {
            ruleId: 'NK012',
            title: this.title,
            severity: 'warning',
            confidence: facts.usesRefresh ? 'high' : 'medium',
            range: callRange(call),
            message:
              'RedactingLogInterceptor prints bodies (logBodies: true) without a bodySanitizer, so tokens in bodies are logged.',
            recommendation: 'Pass a bodySanitizer that masks token fields, or keep logBodies off.',
            resources: [DOC.logging, API.logInterceptor],
          }),
        );
      }
    }
    return out;
  },
};
