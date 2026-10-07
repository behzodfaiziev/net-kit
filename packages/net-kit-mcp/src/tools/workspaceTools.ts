import type { McpServer } from '@modelcontextprotocol/server';
import * as z from 'zod/v4';

import {
  analyzeWorkspace,
  managerConfigurations,
  type AnalysisResult,
} from '../analyzer/engine.js';
import { uploadInventory } from '../analyzer/inventory.js';
import { namedArg } from '../analyzer/model.js';
import { managerCalls } from '../analyzer/rules/helpers.js';
import { REVIEW_RULES, RULE_CATALOG } from '../analyzer/rules/index.js';
import {
  detectMigrationHits,
  MANUAL_MIGRATION_CHECKS,
  MIGRATION_ITEMS,
} from '../analyzer/rules/migration.js';
import type { KnowledgeBase } from '../knowledge/knowledgeBase.js';
import { DOC } from '../knowledge/refs.js';
import { acquireRoots, type RootPolicy } from '../server/roots.js';
import type { Logger } from '../util/log.js';
import type { WorkspaceLimits } from '../workspace/limits.js';
import { selectRoot, type AuthorizedRoot } from '../workspace/roots.js';
import { WorkspaceSession } from '../workspace/session.js';
import { errorResult, ok } from './result.js';
import { analysisOutputSchema, rangeSchema, workspaceInput } from './schemas.js';

/**
 * Workspace tools: read-only analysis of an authorized project root.
 *
 * Capability group `workspace`. These tools touch the local filesystem and
 * are registered only when the server runs with local workspace access.
 */

export interface WorkspaceToolDeps {
  readonly server: McpServer;
  readonly knowledge: () => KnowledgeBase;
  readonly policy: RootPolicy;
  readonly limits: WorkspaceLimits;
  readonly logger: Logger;
}

const ANNOTATIONS = {
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
} as const;

const SEMANTICS = [
  'ORIGINAL API 401 → may trigger one shared refresh and one retry; it never ends the session.',
  'REFRESH ENDPOINT 401 → the session is invalidated: tokens cleared, onSessionInvalidated called once, waiters get ApiFailureType.sessionInvalidated.',
  'TRANSIENT REFRESH FAILURE (offline, DNS, TLS, timeout, 429, 5xx, other 4xx, malformed or token-less response) → session preserved; the caller gets the real failure type with fromRefresh == true.',
];

function summarize(
  tool: string,
  version: string,
  root: AuthorizedRoot,
  result: AnalysisResult,
): string {
  const lines = [
    `${tool} · net_kit ${version} knowledge · ${root.id} (${root.name}) · ${result.stats.filesAnalyzed} relevant file(s) of ${result.stats.filesDiscovered} discovered · ${result.findings.length} finding(s). Read-only: nothing was modified.`,
  ];
  for (const f of result.findings.slice(0, 25)) {
    lines.push(
      `- [${f.severity}/${f.confidence}] ${f.ruleId} ${f.file}:${f.range.startLine} — ${f.title}`,
    );
  }
  if (result.findings.length > 25)
    lines.push(`- … ${result.findings.length - 25} more in the structured result`);
  if (result.stats.truncated) lines.push('Note: limits were reached; results are partial.');
  return lines.join('\n');
}

function baseStructured(
  tool: string,
  kb: KnowledgeBase,
  root: AuthorizedRoot,
  result: AnalysisResult,
  notes: readonly string[],
) {
  return {
    netKitVersion: kb.version,
    tool,
    summary: `${result.findings.length} finding(s) in ${result.stats.filesAnalyzed} relevant file(s).`,
    project: {
      root: { id: root.id, name: root.name },
      netKitConstraint: result.facts.netKitConstraint,
      resolvedNetKitVersion: result.facts.resolvedNetKitVersion,
      targetMajor: result.facts.targetMajor,
      apiHosts: [...result.facts.apiHosts],
    },
    findings: result.findings.map((f) => ({ ...f, resources: [...f.resources] })),
    stats: { scopes: [...result.scopes], ...result.stats },
    notes: [...notes, ...result.notes],
    readOnly: true as const,
    sourceExcerptsAreUntrusted: true as const,
  };
}

interface AnalysisToolSpec<D extends z.ZodType> {
  readonly name: string;
  readonly title: string;
  readonly description: string;
  readonly ruleIds?: readonly string[];
  readonly extraInput?: Record<string, z.ZodType>;
  readonly details: D;
  readonly buildDetails: (result: AnalysisResult) => z.infer<D>;
}

function registerAnalysisTool<D extends z.ZodType>(
  deps: WorkspaceToolDeps,
  spec: AnalysisToolSpec<D>,
): void {
  const { server, knowledge, policy, limits, logger } = deps;
  const inputSchema = z.object({ ...workspaceInput, ...(spec.extraInput ?? {}) });
  server.registerTool(
    spec.name,
    {
      title: spec.title,
      description: spec.description,
      inputSchema,
      outputSchema: analysisOutputSchema.extend({ details: spec.details }),
      annotations: ANNOTATIONS,
    },
    (args, ctx) => {
      const started = Date.now();
      try {
        const acquired = acquireRoots(policy, ctx, server);
        if (acquired.kind === 'input') {
          return acquired.result;
        }
        const root = selectRoot(acquired.roots, args.root);
        const session = new WorkspaceSession(root, limits);
        const extraRules = (args as { rules?: string[] }).rules;
        const ruleIds =
          extraRules !== undefined && extraRules.length > 0 ? extraRules : spec.ruleIds;
        const result = analyzeWorkspace(session, {
          ...(args.paths === undefined ? {} : { paths: args.paths }),
          ...(ruleIds === undefined ? {} : { ruleIds }),
        });
        const kb = knowledge();
        const structured = {
          ...baseStructured(spec.name, kb, root, result, acquired.notes),
          details: spec.buildDetails(result),
        };
        return ok(summarize(spec.name, kb.version, root, result), structured);
      } catch (error) {
        return errorResult(error, logger, spec.name);
      } finally {
        logger.debug(`${spec.name} finished in ${Date.now() - started} ms`);
      }
    },
  );
}

export function registerWorkspaceTools(deps: WorkspaceToolDeps): void {
  const { server, policy, limits, logger } = deps;

  server.registerTool(
    'list_workspace_roots',
    {
      title: 'List authorized workspace roots',
      description:
        'Lists the project roots this server may read (ids and names only, never absolute paths). Workspace tools accept a root id or name.',
      outputSchema: z.object({
        source: z.enum(['startup', 'client']),
        roots: z.array(z.object({ id: z.string(), name: z.string() })),
        notes: z.array(z.string()),
        limits: z.object({
          maxFileBytes: z.number(),
          maxFiles: z.number(),
          maxTotalBytes: z.number(),
          maxDiagnostics: z.number(),
        }),
      }),
      annotations: ANNOTATIONS,
    },
    (ctx) => {
      try {
        const acquired = acquireRoots(policy, ctx, server);
        if (acquired.kind === 'input') return acquired.result;
        const roots = acquired.roots.map((r) => ({ id: r.id, name: r.name }));
        const structured = {
          source: policy.mode,
          roots,
          notes: [...acquired.notes],
          limits: {
            maxFileBytes: limits.maxFileBytes,
            maxFiles: limits.maxFiles,
            maxTotalBytes: limits.maxTotalBytes,
            maxDiagnostics: limits.maxDiagnostics,
          },
        };
        const text =
          roots.length === 0
            ? 'No workspace root is authorized.'
            : `Authorized roots (${policy.mode}): ${roots.map((r) => `${r.id} (${r.name})`).join(', ')}`;
        return ok(text, structured);
      } catch (error) {
        return errorResult(error, logger, 'list_workspace_roots');
      }
    },
  );

  registerAnalysisTool(deps, {
    name: 'inspect_netkit_usage',
    title: 'Inspect net_kit usage',
    description:
      'Runs every net_kit semantic rule (NK001–NK016) over an authorized project root and returns structured diagnostics with confidence levels, citations, and suggested changes (never applied). Static analysis only; no code is executed.',
    extraInput: {
      rules: z
        .array(z.string().regex(/^NK\d{3}$/))
        .max(32)
        .optional()
        .describe('Restrict to these rule ids.'),
    },
    details: z.object({
      rules: z.array(
        z.object({ id: z.string(), title: z.string(), categories: z.array(z.string()) }),
      ),
    }),
    buildDetails: () => ({
      rules: RULE_CATALOG.map((r) => ({ id: r.id, title: r.title, categories: [...r.categories] })),
    }),
  });

  registerAnalysisTool(deps, {
    name: 'review_auth_flow',
    title: 'Review authentication flow',
    description:
      'Reviews AuthPolicy selection, token attachment, public endpoints, external origins, credentials on raw requests, and sign-out handling.',
    ruleIds: REVIEW_RULES.auth,
    details: z.object({
      authPolicyUsage: z.object({ inherit: z.number(), none: z.number(), required: z.number() }),
      managers: z.array(
        z.object({
          file: z.string(),
          range: rangeSchema,
          allowCrossOriginRequests: z.boolean(),
          baseUrlHost: z.string().nullable(),
        }),
      ),
    }),
    buildDetails: (result) => {
      const usage = { inherit: 0, none: 0, required: 0 };
      for (const file of result.files) {
        for (const call of managerCalls(file)) {
          const policyText = namedArg(call, 'authPolicy')?.text ?? 'AuthPolicy.inherit';
          if (policyText.endsWith('.none')) usage.none++;
          else if (policyText.endsWith('.required')) usage.required++;
          else usage.inherit++;
        }
      }
      return {
        authPolicyUsage: usage,
        managers: managerConfigurations(result.files).map((m) => ({
          file: m.file,
          range: m.range,
          allowCrossOriginRequests: m.arguments.allowCrossOriginRequests === 'true',
          baseUrlHost: m.baseUrlHost,
        })),
      };
    },
  });

  registerAnalysisTool(deps, {
    name: 'review_refresh_flow',
    title: 'Review token refresh and session handling',
    description:
      'Checks refresh configuration and looks for sign-out logic that runs on something other than the refresh endpoint answering 401 (offline, timeouts, any 401, generic errors).',
    ruleIds: REVIEW_RULES.refresh,
    details: z.object({
      semantics: z.array(z.string()),
      managers: z.array(
        z.object({
          file: z.string(),
          range: rangeSchema,
          refreshConfigured: z.boolean(),
          onSessionInvalidated: z.boolean(),
          onTokenRefreshed: z.boolean(),
          onBeforeRefreshRequest: z.boolean(),
        }),
      ),
    }),
    buildDetails: (result) => ({
      semantics: SEMANTICS,
      managers: managerConfigurations(result.files).map((m) => ({
        file: m.file,
        range: m.range,
        refreshConfigured: m.refresh.configured,
        onSessionInvalidated: m.refresh.onSessionInvalidated,
        onTokenRefreshed: m.refresh.onTokenRefreshed,
        onBeforeRefreshRequest: m.refresh.onBeforeRefreshRequest,
      })),
    }),
  });

  registerAnalysisTool(deps, {
    name: 'review_upload_flow',
    title: 'Review uploads',
    description:
      'Classifies every upload (authenticated replayable upload to the API vs. external signed-URL upload) and checks memory use, replayability, cancellation, and credential leakage.',
    ruleIds: REVIEW_RULES.upload,
    details: z.object({
      uploads: z.array(
        z.object({
          file: z.string(),
          line: z.number(),
          design: z.string(),
          destination: z.enum(['api', 'external', 'unknown']),
          replayable: z.boolean(),
          cancellable: z.boolean(),
          progress: z.boolean(),
        }),
      ),
    }),
    buildDetails: (result) => ({ uploads: uploadInventory(result.files) }),
  });

  registerAnalysisTool(deps, {
    name: 'review_streaming_usage',
    title: 'Review streaming',
    description:
      'Finds large downloads buffered with send(), single-shot stream bodies where a replayable body fits, and files read into memory before upload.',
    ruleIds: REVIEW_RULES.streaming,
    details: z.object({ sendCalls: z.number(), sendStreamedCalls: z.number() }),
    buildDetails: (result) => {
      let send = 0;
      let streamed = 0;
      for (const file of result.files) {
        for (const call of file.calls) {
          if (call.isMember && call.name === 'send') send++;
          if (call.isMember && call.name === 'sendStreamed') streamed++;
        }
      }
      return { sendCalls: send, sendStreamedCalls: streamed };
    },
  });

  registerAnalysisTool(deps, {
    name: 'check_v5_to_v6_migration',
    title: 'Check net_kit 5.x → 6 migration',
    description:
      'Detects net_kit 5.x APIs (Dio re-export, Options, CancelToken, FormData, auth flags, onRefreshFailed, constructor options) and returns a project-specific migration checklist backed by MIGRATION.md.',
    ruleIds: REVIEW_RULES.migration,
    details: z.object({
      checklist: z.array(
        z.object({
          item: z.string(),
          v5: z.string(),
          v6: z.string(),
          behavioral: z.boolean(),
          occurrences: z.array(
            z.object({ file: z.string(), line: z.number(), detail: z.string() }),
          ),
          resource: z.string(),
        }),
      ),
      manualChecks: z.array(z.object({ item: z.string(), resource: z.string() })),
    }),
    buildDetails: (result) => {
      const hits = detectMigrationHits(result.files);
      return {
        checklist: MIGRATION_ITEMS.map((entry) => ({
          item: entry.id,
          v5: entry.v5,
          v6: entry.v6,
          behavioral: entry.behavioral,
          occurrences: hits
            .filter((h) => h.item.id === entry.id)
            .map((h) => ({ file: h.file.path, line: h.range.startLine, detail: h.detail })),
          resource: entry.resource,
        })).filter((entry) => entry.occurrences.length > 0),
        manualChecks: MANUAL_MIGRATION_CHECKS.map((m) => ({ item: m.item, resource: m.resource })),
      };
    },
  });

  registerAnalysisTool(deps, {
    name: 'validate_netkit_configuration',
    title: 'Validate NetKitManager configuration',
    description:
      'Reports every NetKitManager construction (base URL, refresh, origin, logging, timeouts, custom transport) and flags risky settings. Argument values that may hold secrets are reported only as "(set)".',
    ruleIds: REVIEW_RULES.configuration,
    details: z.object({
      managers: z.array(
        z.object({
          file: z.string(),
          range: rangeSchema,
          arguments: z.record(z.string(), z.string()),
          baseUrlHost: z.string().nullable(),
          refreshConfigured: z.boolean(),
          onSessionInvalidated: z.boolean(),
          customTransport: z.boolean(),
          interceptors: z.boolean(),
        }),
      ),
      resources: z.array(z.string()),
    }),
    buildDetails: (result) => ({
      managers: managerConfigurations(result.files).map((m) => ({
        file: m.file,
        range: m.range,
        arguments: { ...m.arguments },
        baseUrlHost: m.baseUrlHost,
        refreshConfigured: m.refresh.configured,
        onSessionInvalidated: m.refresh.onSessionInvalidated,
        customTransport: m.customTransport,
        interceptors: m.interceptors,
      })),
      resources: [DOC.authPolicy, DOC.sessionRules, DOC.logging, DOC.originPolicy],
    }),
  });
}
