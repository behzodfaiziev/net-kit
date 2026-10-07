import { DOC } from '../../knowledge/refs.js';
import { identifiers, namedArg, type CallSite, type DartFile } from '../model.js';
import type { Finding, ProjectFacts, Rule, Severity } from '../types.js';
import {
  callRange,
  callText,
  finding,
  importsDio,
  managerCalls,
  managerConstructions,
  tokenRange,
  usesNetKit,
} from './helpers.js';

/** One line of the 5.x → 6.0 breaking-change ledger the analyzer can detect. */
export interface MigrationItem {
  readonly id: string;
  readonly v5: string;
  readonly v6: string;
  readonly resource: string;
  /** Changes runtime behavior (not only compilation). */
  readonly behavioral: boolean;
}

export const MIGRATION_ITEMS: readonly MigrationItem[] = [
  {
    id: 'auth-flags',
    v5: 'containsAccessToken / skipTokenRefresh',
    v6: 'authPolicy: AuthPolicy.inherit | none | required',
    resource: DOC.migrationAuthPolicy,
    behavioral: true,
  },
  {
    id: 'cancel-token',
    v5: 'cancelToken: CancelToken()',
    v6: 'cancellationToken: NetKitCancellationToken()',
    resource: DOC.migrationRequest,
    behavioral: false,
  },
  {
    id: 'request-options',
    v5: 'options: Options(headers: ..., receiveTimeout: ...)',
    v6: 'headers: {...}, timeout: NetKitTimeout(...)',
    resource: DOC.migrationRequest,
    behavioral: false,
  },
  {
    id: 'base-options',
    v5: 'NetKitManager(baseOptions: BaseOptions(...))',
    v6: 'NetKitManager(headers: {...}, timeout: NetKitTimeout(...))',
    resource: DOC.migrationConstructor,
    behavioral: false,
  },
  {
    id: 'http-client-adapter',
    v5: 'NetKitManager(httpClientAdapter: adapter)',
    v6: "NetKitManager(transport: DioNetKitTransport(httpClientAdapter: adapter)) with import 'package:net_kit/net_kit_dio.dart'",
    resource: DOC.migrationConstructor,
    behavioral: false,
  },
  {
    id: 'dio-interceptor',
    v5: 'NetKitManager(interceptor: Interceptor)',
    v6: 'NetKitManager(interceptors: [NetKitInterceptor])',
    resource: DOC.migrationInterceptor,
    behavioral: false,
  },
  {
    id: 'test-mode',
    v5: 'NetKitManager(testMode: ...)',
    v6: 'NetKitManager(devMode: ...)',
    resource: DOC.migrationConstructor,
    behavioral: false,
  },
  {
    id: 'on-refresh-failed',
    v5: 'onRefreshFailed (called for every refresh failure)',
    v6: 'onSessionInvalidated (called only when the refresh endpoint answers 401)',
    resource: DOC.migrationSession,
    behavioral: true,
  },
  {
    id: 'dio-reexport',
    v5: "Dio types (Options, CancelToken, FormData, MultipartFile, BaseOptions, DioException, ...) through 'package:net_kit/net_kit.dart'",
    v6: "net_kit-owned types, or import 'package:net_kit/net_kit_dio.dart' / package:dio explicitly",
    resource: DOC.migrationLedger,
    behavioral: false,
  },
  {
    id: 'multipart-types',
    v5: 'uploadFormData(formData: FormData) / uploadMultipartData(multipartFile: MultipartFile)',
    v6: 'NetKitFormData / NetKitMultipartFile (fromPath streams from disk)',
    resource: DOC.migrationMultipart,
    behavioral: false,
  },
  {
    id: 'raw-client',
    v5: 'DioRawHttpClient() / DioRawHttpClient.test(...) from net_kit.dart',
    v6: "netKitManager.transport, or DioNetKitTransport(...) from 'package:net_kit/net_kit_dio.dart'",
    resource: DOC.migrationRawClient,
    behavioral: false,
  },
  {
    id: 'raw-timeouts',
    v5: 'RawHttpRequest(connectTimeout:, sendTimeout:, receiveTimeout:)',
    v6: 'RawHttpRequest(timeout: NetKitTimeout(connect:, send:, receive:))',
    resource: DOC.migrationLedger,
    behavioral: false,
  },
  {
    id: 'dio-exception',
    v5: 'catching DioException around net_kit calls',
    v6: 'catch ApiException and switch on ApiException.type',
    resource: DOC.migrationErrors,
    behavioral: true,
  },
  {
    id: 'extract-tokens',
    v5: 'extractTokens(response: Response)',
    v6: 'extractTokens(statusCode:, data:) (visible for testing)',
    resource: DOC.migrationLedger,
    behavioral: false,
  },
];

/** Ledger entries that cannot be detected statically and need a manual check. */
export const MANUAL_MIGRATION_CHECKS: readonly {
  readonly item: string;
  readonly resource: string;
}[] = [
  {
    item: 'allowCrossOriginRequests now defaults to false: absolute URLs on another origin are rejected unless enabled, and never receive stored credentials.',
    resource: DOC.originPolicy,
  },
  {
    item: 'uploadFile streams the file from disk and reopens it on retry; code that relied on it buffering is unaffected, but memory use drops.',
    resource: DOC.largeUploads,
  },
  {
    item: 'RawHttpResponse.body is now bodyBytes (List<int>); header(name) returns the first value; use headerValues(name) for repeated headers.',
    resource: DOC.migrationLedger,
  },
  {
    item: 'A 401 with no refreshTokenPath is returned to the caller instead of failing with "Refresh token path is not set".',
    resource: DOC.migrationLedger,
  },
  {
    item: 'Redirects are followed by NetKitManager under the origin policy; the raw transport no longer follows redirects unless RawHttpRequest(followRedirects: true).',
    resource: DOC.originPolicy,
  },
];

export interface MigrationHit {
  readonly item: MigrationItem;
  readonly file: DartFile;
  readonly call?: CallSite;
  readonly range: ReturnType<typeof callRange>;
  readonly detail: string;
}

const DIO_TYPES =
  /^(Options|CancelToken|FormData|MultipartFile|BaseOptions|InterceptorsWrapper|LogInterceptor|DioException|DioExceptionType|ProgressCallback|Interceptor|HttpClientAdapter|RequestOptions|Response|ResponseType|Headers)$/;

function item(id: string): MigrationItem {
  const found = MIGRATION_ITEMS.find((entry) => entry.id === id);
  if (found === undefined) throw new Error(`unknown migration item ${id}`);
  return found;
}

/** Detects 5.x API usage in [files]. */
export function detectMigrationHits(files: readonly DartFile[]): MigrationHit[] {
  const hits: MigrationHit[] = [];
  for (const file of files) {
    const netKit = usesNetKit(file);
    if (!netKit) continue;

    for (const call of managerCalls(file)) {
      for (const [arg, id] of [
        ['containsAccessToken', 'auth-flags'],
        ['skipTokenRefresh', 'auth-flags'],
        ['cancelToken', 'cancel-token'],
        ['options', 'request-options'],
      ] as const) {
        if (namedArg(call, arg) !== undefined) {
          hits.push({
            item: item(id),
            file,
            call,
            range: callRange(call),
            detail: `${call.name}(${arg}: ...)`,
          });
        }
      }
      for (const arg of ['formData', 'multipartFile']) {
        const value = namedArg(call, arg);
        if (
          value !== undefined &&
          identifiers(value.tokens).some((n) => n === 'FormData' || n === 'MultipartFile')
        ) {
          hits.push({
            item: item('multipart-types'),
            file,
            call,
            range: callRange(call),
            detail: `${call.name}(${arg}: Dio type)`,
          });
        }
      }
    }

    for (const call of managerConstructions(file)) {
      for (const [arg, id] of [
        ['baseOptions', 'base-options'],
        ['httpClientAdapter', 'http-client-adapter'],
        ['interceptor', 'dio-interceptor'],
        ['testMode', 'test-mode'],
        ['onRefreshFailed', 'on-refresh-failed'],
      ] as const) {
        if (namedArg(call, arg) !== undefined) {
          hits.push({
            item: item(id),
            file,
            call,
            range: callRange(call),
            detail: `NetKitManager(${arg}: ...)`,
          });
        }
      }
    }

    for (const call of file.calls) {
      if (call.name === 'RawHttpRequest' && !call.isMember) {
        for (const arg of ['connectTimeout', 'sendTimeout', 'receiveTimeout']) {
          if (namedArg(call, arg) !== undefined) {
            hits.push({
              item: item('raw-timeouts'),
              file,
              call,
              range: callRange(call),
              detail: `RawHttpRequest(${arg}: ...)`,
            });
          }
        }
      }
      if (
        call.name === 'DioRawHttpClient' ||
        (call.qualifier === 'DioRawHttpClient' && call.name === 'test')
      ) {
        hits.push({
          item: item('raw-client'),
          file,
          call,
          range: callRange(call),
          detail: callText(file, call, 80),
        });
      }
      if (call.name === 'extractTokens' && namedArg(call, 'response') !== undefined) {
        hits.push({
          item: item('extract-tokens'),
          file,
          call,
          range: callRange(call),
          detail: 'extractTokens(response: ...)',
        });
      }
    }

    // Dio types used without importing Dio: relied on the removed re-export.
    if (!importsDio(file) && !file.imports.includes('package:net_kit/net_kit_dio.dart')) {
      const reported = new Set<string>();
      for (let i = 0; i < file.tokens.length; i++) {
        const token = file.tokens[i];
        if (token?.kind !== 'ident' || !DIO_TYPES.test(token.text)) continue;
        // Skip member names (`x.Response`) and named-argument labels (`headers:`).
        const previous = file.tokens[i - 1]?.text;
        const next = file.tokens[i + 1]?.text;
        if (previous === '.' || next === ':') continue;
        if (
          token.text === 'Response' ||
          token.text === 'Headers' ||
          token.text === 'RequestOptions'
        ) {
          // Too generic on their own; require a Dio-specific neighbour.
          if (!/\b(Dio|dio)\b/.test(file.text)) continue;
        }
        const key = `${token.text}:${token.line}`;
        if (reported.has(key)) continue;
        reported.add(key);
        const id =
          token.text === 'DioException' || token.text === 'DioExceptionType'
            ? 'dio-exception'
            : 'dio-reexport';
        hits.push({ item: item(id), file, range: tokenRange([token]), detail: token.text });
      }
    } else {
      for (let i = 0; i < file.tokens.length; i++) {
        const token = file.tokens[i];
        if (
          token?.text === 'DioException' &&
          file.tokens[i + 1]?.text === 'catch' &&
          file.tokens[i - 1]?.text === 'on'
        ) {
          hits.push({
            item: item('dio-exception'),
            file,
            range: tokenRange([token]),
            detail: 'on DioException catch',
          });
        }
      }
    }
  }
  return hits;
}

function severityFor(facts: ProjectFacts): Severity {
  if (facts.targetMajor === 6) return 'error';
  if (facts.targetMajor !== null && facts.targetMajor < 6) return 'info';
  return 'warning';
}

/** NK005: 5.x API usage. */
export const nk005: Rule = {
  id: 'NK005',
  title: 'net_kit 5.x API usage',
  categories: ['migration', 'auth', 'refresh'],
  description:
    'APIs removed or changed in net_kit 6: Dio-typed parameters and re-exports, the containsAccessToken/skipTokenRefresh flags, onRefreshFailed, and constructor options.',
  run({ files, facts }) {
    const severity = severityFor(facts);
    return detectMigrationHits(files).map((hit): Finding =>
      finding(hit.file, {
        ruleId: 'NK005',
        title: this.title,
        severity: hit.item.behavioral && severity === 'info' ? 'warning' : severity,
        confidence: hit.item.id === 'dio-reexport' ? 'medium' : 'high',
        range: hit.range,
        message:
          `${hit.detail}: ${hit.item.v5} changed in net_kit 6.` +
          (hit.item.behavioral
            ? ' This also changes runtime behavior, not only compilation.'
            : '') +
          (facts.targetMajor === 6
            ? ' The project depends on net_kit 6, so this does not compile or behaves differently.'
            : ''),
        recommendation: `Use ${hit.item.v6}.`,
        resources: [hit.item.resource, DOC.migrationChecklist],
        ...(hit.call === undefined
          ? {}
          : {
              suggestion: {
                currentPattern: callText(hit.file, hit.call),
                suggestedPattern: hit.item.v6,
                explanation: 'See the migration guide entry for a full before/after example.',
              },
            }),
      }),
    );
  },
};
