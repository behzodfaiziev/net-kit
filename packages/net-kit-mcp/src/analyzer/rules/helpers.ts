import type { Token } from '../../dart/lexer.js';
import { redactCode } from '../../util/redactCode.js';
import { callText, identifiers, stringValues, type CallSite, type DartFile } from '../model.js';
import type { Confidence, Finding, Range, Severity, Suggestion } from '../types.js';

/** `NetKitManager` request and upload methods. */
export const MANAGER_METHODS: ReadonlySet<string> = new Set([
  'requestModel',
  'requestModelMeta',
  'requestList',
  'requestListMeta',
  'requestVoid',
  'uploadMultipartData',
  'uploadFormData',
  'uploadRawData',
  'uploadFile',
]);

export const UPLOAD_METHODS: ReadonlySet<string> = new Set([
  'uploadMultipartData',
  'uploadFormData',
  'uploadRawData',
  'uploadFile',
]);

/** Whether the file uses net_kit at all. */
export function usesNetKit(file: DartFile): boolean {
  return (
    file.imports.some((uri) => uri.startsWith('package:net_kit/')) ||
    /\b(NetKitManager|INetKitManager|RawHttpClient|NetKitTransport)\b/.test(file.text)
  );
}

/** Whether the file imports Dio directly (not through net_kit). */
export function importsDio(file: DartFile): boolean {
  return file.imports.some((uri) => uri.startsWith('package:dio/'));
}

export function importsNetKitDio(file: DartFile): boolean {
  return file.imports.includes('package:net_kit/net_kit_dio.dart');
}

/** Calls to `NetKitManager` methods (member calls with a net_kit method name). */
export function managerCalls(file: DartFile): CallSite[] {
  return file.calls.filter((call) => call.isMember && MANAGER_METHODS.has(call.name));
}

/** `NetKitManager(...)` constructions. */
export function managerConstructions(file: DartFile): CallSite[] {
  return file.calls.filter((call) => call.name === 'NetKitManager' && !call.isMember);
}

export function callRange(call: CallSite): Range {
  return {
    startLine: call.line,
    startColumn: call.column,
    endLine: call.endLine,
    endColumn: call.endColumn,
  };
}

export function tokenRange(tokens: readonly Token[]): Range {
  const first = tokens[0];
  const last = tokens[tokens.length - 1];
  return {
    startLine: first?.line ?? 1,
    startColumn: first?.column ?? 1,
    endLine: last?.line ?? first?.line ?? 1,
    endColumn: (last?.column ?? 1) + (last?.text.length ?? 0),
  };
}

const SIGNED_QUERY =
  /(?:^|[?&])(x-amz-signature|x-amz-credential|x-goog-signature|x-goog-credential|signature|sig|se|sp|sv|key-pair-id|policy|token)=/i;
const STORAGE_HOST =
  /(amazonaws\.com|storage\.googleapis\.com|googleusercontent\.com|blob\.core\.windows\.net|r2\.cloudflarestorage\.com|digitaloceanspaces\.com|backblazeb2\.com|cloudfront\.net|(^|\.)storage\.|(^|\.)cdn\.|(^|\.)uploads?\.)/i;
const SIGNED_NAME =
  /(signed|presigned|presign|upload|storage|bucket|s3|gcs|blob|object)_?(url|uri|link|endpoint|location)s?$/i;

export interface UrlEvidence {
  readonly kind:
    'signed-literal' | 'storage-literal' | 'external-literal' | 'signed-identifier' | 'none';
  readonly host: string | null;
  readonly detail: string;
}

export function hostOf(url: string): string | null {
  const match = /^https?:\/\/([^/?#:]+)/i.exec(url);
  return match?.[1]?.toLowerCase() ?? null;
}

/** Classifies the destination expression of a request. */
export function urlEvidence(tokens: readonly Token[]): UrlEvidence {
  for (const value of stringValues(tokens)) {
    if (!/^https?:\/\//i.test(value)) continue;
    const host = hostOf(value);
    const query = value.includes('?') ? value.slice(value.indexOf('?')) : '';
    if (SIGNED_QUERY.test(query)) {
      return {
        kind: 'signed-literal',
        host,
        detail: 'URL carries signature/credential query parameters',
      };
    }
    if (host !== null && STORAGE_HOST.test(host)) {
      return {
        kind: 'storage-literal',
        host,
        detail: `host ${host} looks like object storage or a CDN`,
      };
    }
    return { kind: 'external-literal', host, detail: `absolute URL to ${host ?? 'another host'}` };
  }
  const names = identifiers(tokens);
  for (let i = 0; i < names.length; i++) {
    const name = names[i] ?? '';
    const next = names[i + 1] ?? '';
    if (SIGNED_NAME.test(name)) {
      return { kind: 'signed-identifier', host: null, detail: `value comes from \`${name}\`` };
    }
    // `signed.url`, `upload.uri`, `presigned.location`
    if (
      /^(signed|presigned|presign|upload|storage|signedUpload|uploadTarget|target)\w*$/i.test(
        name,
      ) &&
      /^(url|uri|location|href)$/i.test(next)
    ) {
      return {
        kind: 'signed-identifier',
        host: null,
        detail: `value comes from \`${name}.${next}\``,
      };
    }
  }
  return { kind: 'none', host: null, detail: '' };
}

export function finding(
  file: DartFile,
  init: {
    ruleId: string;
    title: string;
    severity: Severity;
    confidence: Confidence;
    range: Range;
    message: string;
    recommendation: string;
    resources: readonly string[];
    suggestion?: Omit<Suggestion, 'label'>;
  },
): Finding {
  const { suggestion, ...rest } = init;
  return {
    ...rest,
    message: redactCode(rest.message),
    file: file.path,
    ...(suggestion === undefined
      ? {}
      : {
          suggestion: {
            label: 'SUGGESTED — NOT APPLIED',
            currentPattern: redactCode(suggestion.currentPattern),
            suggestedPattern: redactCode(suggestion.suggestedPattern),
            explanation: suggestion.explanation,
          },
        }),
  };
}

export { callText };
