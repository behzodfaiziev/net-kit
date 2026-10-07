import { redactCode } from '../util/redactCode.js';
import { WorkspaceError } from '../workspace/errors.js';
import type { WorkspaceSession } from '../workspace/session.js';
import { namedArg, parseDartFile, stringValues, type DartFile } from './model.js';
import { lockedNetKitVersion, majorOf, netKitConstraint } from './project.js';
import { callRange, managerConstructions } from './rules/helpers.js';
import { RULES } from './rules/index.js';
import { literalApiHosts } from './rules/transport.js';
import type { Finding, ProjectFacts, Range, Severity } from './types.js';

/**
 * Runs the semantic rules over one authorized root.
 *
 * Discovery is targeted: by default only `lib/` (or the root when there is
 * no `lib/`) plus `pubspec.yaml` and `pubspec.lock`. Every read goes
 * through the request's [WorkspaceSession], so root confinement, the
 * sensitive-file policy, and the budgets apply. Source text is parsed as
 * data and discarded when the request ends.
 */

export interface AnalysisOptions {
  /** Root-relative files or directories to analyze. */
  readonly paths?: readonly string[];
  /** Rules to run; all when omitted. */
  readonly ruleIds?: readonly string[];
}

export interface AnalysisStats {
  readonly filesDiscovered: number;
  readonly filesAnalyzed: number;
  readonly bytesRead: number;
  readonly skippedFiles: number;
  readonly skippedSensitiveFiles: number;
  readonly skippedSymlinks: number;
  readonly truncated: boolean;
  readonly diagnosticsTruncated: boolean;
}

export interface AnalysisResult {
  readonly facts: ProjectFacts;
  readonly findings: readonly Finding[];
  readonly files: readonly DartFile[];
  readonly scopes: readonly string[];
  readonly stats: AnalysisStats;
  readonly notes: readonly string[];
}

const RELEVANT =
  /net_kit|NetKit|RawHttp|readAsBytes|package:dio|\bDio\(|log_?out|sign_?out|ApiException|onSessionInvalidated|onRefreshFailed/i;

const SEVERITY_ORDER: Record<Severity, number> = { error: 0, warning: 1, info: 2 };

function defaultScopes(session: WorkspaceSession): string[] {
  try {
    session.resolve('lib', { allowDirectory: true });
    return ['lib'];
  } catch {
    return ['.'];
  }
}

export function analyzeWorkspace(
  session: WorkspaceSession,
  options: AnalysisOptions = {},
): AnalysisResult {
  const notes: string[] = [];
  const scopes =
    options.paths !== undefined && options.paths.length > 0
      ? [...options.paths]
      : defaultScopes(session);

  const pubspec = session.tryReadText('pubspec.yaml');
  const lock = session.tryReadText('pubspec.lock', { allowLockFile: true });
  const constraint = pubspec === null ? null : netKitConstraint(pubspec);
  const resolved = lock === null ? null : lockedNetKitVersion(lock);
  if (pubspec === null)
    notes.push('No readable pubspec.yaml at the root; the net_kit version is unknown.');
  else if (constraint === null) notes.push('pubspec.yaml does not declare a net_kit dependency.');

  const candidates = session.discover(scopes, (rel) => rel.endsWith('.dart'));
  const files: DartFile[] = [];
  let skipped = 0;
  for (const rel of candidates) {
    let text: string;
    try {
      text = session.readText(rel);
    } catch (error) {
      if (error instanceof WorkspaceError && error.code === 'limit_exceeded') {
        notes.push(`Stopped reading files: ${error.message}`);
        break;
      }
      skipped++;
      continue;
    }
    if (RELEVANT.test(text)) {
      files.push(parseDartFile(rel, text));
    }
  }

  const facts: ProjectFacts = {
    netKitConstraint: constraint,
    resolvedNetKitVersion: resolved,
    targetMajor: majorOf(resolved) ?? majorOf(constraint),
    apiHosts: literalApiHosts(files),
    usesRefresh: files.some((file) =>
      managerConstructions(file).some((call) => namedArg(call, 'refreshTokenPath') !== undefined),
    ),
  };

  const selected =
    options.ruleIds === undefined
      ? RULES
      : RULES.filter((rule) => options.ruleIds?.includes(rule.id));
  const all = selected
    .flatMap((rule) => rule.run({ files, facts }))
    .sort(
      (a, b) =>
        SEVERITY_ORDER[a.severity] - SEVERITY_ORDER[b.severity] ||
        a.file.localeCompare(b.file) ||
        a.range.startLine - b.range.startLine ||
        a.ruleId.localeCompare(b.ruleId),
    );
  const max = session.limits.maxDiagnostics;
  const findings = all.slice(0, max);
  if (all.length > max) notes.push(`Showing ${max} of ${all.length} findings (diagnostic limit).`);

  const stats = session.stats;
  return {
    facts,
    findings,
    files,
    scopes,
    stats: {
      filesDiscovered: candidates.length,
      filesAnalyzed: files.length,
      bytesRead: stats.bytesRead,
      skippedFiles: skipped,
      skippedSensitiveFiles: stats.skippedSensitiveFiles,
      skippedSymlinks: stats.skippedSymlinks,
      truncated: stats.truncated,
      diagnosticsTruncated: all.length > max,
    },
    notes,
  };
}

const SAFE_CONFIG_ARGS = new Set([
  'baseUrl',
  'devBaseUrl',
  'devMode',
  'refreshTokenPath',
  'allowCrossOriginRequests',
  'logResponseBodies',
  'logInterceptorEnabled',
  'loggerEnabled',
  'timeout',
  'dataKey',
  'metadataDataKey',
  'accessTokenHeaderKey',
  'accessTokenPrefix',
  'accessTokenBodyKey',
  'refreshTokenBodyKey',
  'removeAccessTokenBeforeRefresh',
  'refreshTokenContentType',
  'sensitiveHeaders',
  'sensitiveQueryParameters',
]);

export interface ManagerConfiguration {
  readonly file: string;
  readonly range: Range;
  /** Argument name → value (safe arguments) or `"(set)"`. */
  readonly arguments: Readonly<Record<string, string>>;
  readonly baseUrlHost: string | null;
  readonly refresh: {
    readonly configured: boolean;
    readonly onSessionInvalidated: boolean;
    readonly onTokenRefreshed: boolean;
    readonly onBeforeRefreshRequest: boolean;
  };
  readonly customTransport: boolean;
  readonly interceptors: boolean;
}

/** Configuration facts for every `NetKitManager(...)` construction. */
export function managerConfigurations(files: readonly DartFile[]): ManagerConfiguration[] {
  const out: ManagerConfiguration[] = [];
  for (const file of files) {
    for (const call of managerConstructions(file)) {
      const args: Record<string, string> = {};
      for (const arg of call.args) {
        if (arg.name === null) continue;
        const text = arg.text.length > 160 ? `${arg.text.slice(0, 160)}…` : arg.text;
        args[arg.name] = SAFE_CONFIG_ARGS.has(arg.name) ? redactCode(text) : '(set)';
      }
      const baseUrl = stringValues(namedArg(call, 'baseUrl')?.tokens ?? [])[0];
      out.push({
        file: file.path,
        range: callRange(call),
        arguments: args,
        baseUrlHost:
          baseUrl === undefined ? null : (/^https?:\/\/([^/?#:]+)/i.exec(baseUrl)?.[1] ?? null),
        refresh: {
          configured: namedArg(call, 'refreshTokenPath') !== undefined,
          onSessionInvalidated: namedArg(call, 'onSessionInvalidated') !== undefined,
          onTokenRefreshed: namedArg(call, 'onTokenRefreshed') !== undefined,
          onBeforeRefreshRequest: namedArg(call, 'onBeforeRefreshRequest') !== undefined,
        },
        customTransport: namedArg(call, 'transport') !== undefined,
        interceptors: namedArg(call, 'interceptors') !== undefined,
      });
    }
  }
  return out;
}
