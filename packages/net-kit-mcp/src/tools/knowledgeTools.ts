import type { McpServer } from '@modelcontextprotocol/server';
import * as z from 'zod/v4';

import { apiUri, type KnowledgeBase, SEARCH_AREAS } from '../knowledge/knowledgeBase.js';
import { findPattern, PATTERNS } from '../patterns/catalog.js';
import { recommend } from '../patterns/recommend.js';
import type { Logger } from '../util/log.js';
import { errorResult, ok, toolError } from './result.js';

/**
 * Knowledge tools: answers from the bundled net_kit knowledge only.
 *
 * Capability group `knowledge`. They read no local files at request time
 * and are safe to expose without workspace access.
 */

export interface KnowledgeToolDeps {
  readonly server: McpServer;
  readonly knowledge: () => KnowledgeBase;
  readonly logger: Logger;
}

const ANNOTATIONS = {
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
} as const;

const memberSchema = z.object({
  name: z.string(),
  kind: z.string(),
  signature: z.string(),
  doc: z.string(),
  isStatic: z.boolean(),
  deprecated: z.string().nullable(),
  visibleForTesting: z.boolean(),
});

export function registerKnowledgeTools({ server, knowledge, logger }: KnowledgeToolDeps): void {
  server.registerTool(
    'search_netkit',
    {
      title: 'Search net_kit',
      description:
        'Searches the net_kit public API (source-derived) and documentation (README, token management, migration guide, examples, changelog). Returns ranked excerpts with resource URIs.',
      inputSchema: z.object({
        query: z.string().min(1).max(300),
        limit: z.number().int().min(1).max(25).optional(),
        areas: z.array(z.enum(SEARCH_AREAS)).max(5).optional(),
      }),
      outputSchema: z.object({
        netKitVersion: z.string(),
        query: z.string(),
        matches: z.array(
          z.object({
            kind: z.enum(['symbol', 'section']),
            title: z.string(),
            area: z.string(),
            excerpt: z.string(),
            resource: z.string(),
            source: z.string(),
            score: z.number(),
          }),
        ),
      }),
      annotations: ANNOTATIONS,
    },
    ({ query, limit, areas }) => {
      try {
        const kb = knowledge();
        const matches = kb.search(query, limit ?? 8, areas ?? SEARCH_AREAS);
        const text = [
          `${matches.length} match(es) for "${query}" in net_kit ${kb.version}.`,
          ...matches.map((m) => `- ${m.title} (${m.area}) → ${m.resource}`),
        ].join('\n');
        return ok(text, { netKitVersion: kb.version, query, matches });
      } catch (error) {
        return errorResult(error, logger, 'search_netkit');
      }
    },
  );

  server.registerTool(
    'get_netkit_api',
    {
      title: 'Get net_kit API',
      description:
        'Returns the public declaration of a net_kit symbol as derived from the net_kit source: kind, signature, constructors and members with Dartdoc, entrypoints, and deprecations.',
      inputSchema: z.object({
        symbol: z
          .string()
          .min(1)
          .max(120)
          .describe('Public symbol, e.g. AuthPolicy, NetKitManager, FileRawHttpBody.'),
        member: z.string().max(120).optional().describe('Return only this member.'),
      }),
      outputSchema: z.object({
        netKitVersion: z.string(),
        name: z.string(),
        kind: z.string(),
        signature: z.string(),
        doc: z.string(),
        deprecated: z.string().nullable(),
        entrypoints: z.array(z.string()),
        source: z.string(),
        resource: z.string(),
        members: z.array(memberSchema),
      }),
      annotations: ANNOTATIONS,
    },
    ({ symbol, member }) => {
      try {
        const kb = knowledge();
        const found = kb.symbol(symbol);
        if (found === undefined) {
          const similar = kb.similarSymbols(symbol);
          return toolError(
            'symbol_not_found',
            `"${symbol}" is not a public net_kit ${kb.version} symbol.${similar.length > 0 ? ` Did you mean: ${similar.join(', ')}?` : ''} See netkit://api/index.`,
          );
        }
        let members = found.members;
        if (member !== undefined) {
          members = members.filter((m) => m.name === member || m.name.endsWith(`.${member}`));
          if (members.length === 0) {
            return toolError('member_not_found', `${found.name} has no public member "${member}".`);
          }
        }
        const structured = {
          netKitVersion: kb.version,
          name: found.name,
          kind: found.kind,
          signature: found.signature,
          doc: found.doc,
          deprecated: found.deprecated,
          entrypoints: [...found.entrypoints],
          source: `packages/net-kit/${found.source.file}:${found.source.line}`,
          resource: apiUri(found.name),
          members: members.map((m) => ({
            name: m.name,
            kind: m.kind,
            signature: m.signature,
            doc: m.doc,
            isStatic: m.isStatic,
            deprecated: m.deprecated,
            visibleForTesting: m.visibleForTesting,
          })),
        };
        const text = [
          `${found.kind} ${found.name} (net_kit ${kb.version}, ${found.entrypoints.join(', ')})`,
          found.signature,
          found.doc.split('\n\n')[0] ?? '',
          `${members.length} member(s). Full reference: ${apiUri(found.name)}`,
        ].join('\n');
        return ok(text, structured);
      } catch (error) {
        return errorResult(error, logger, 'get_netkit_api');
      }
    },
  );

  server.registerTool(
    'explain_netkit_pattern',
    {
      title: 'Explain a net_kit pattern',
      description: `Explains an established net_kit pattern: recommended API, rationale, security implications, a short example, and citations. Patterns: ${PATTERNS.map((p) => p.id).join(', ')}.`,
      inputSchema: z.object({ pattern: z.string().min(1).max(120) }),
      outputSchema: z.object({
        netKitVersion: z.string(),
        id: z.string(),
        title: z.string(),
        summary: z.string(),
        recommendedApis: z.array(
          z.object({ name: z.string(), signature: z.string(), resource: z.string() }),
        ),
        why: z.array(z.string()),
        security: z.array(z.string()),
        example: z.string(),
        resources: z.array(z.string()),
      }),
      annotations: ANNOTATIONS,
    },
    ({ pattern }) => {
      try {
        const kb = knowledge();
        const found = findPattern(pattern);
        if (found === undefined) {
          return toolError(
            'pattern_not_found',
            `Unknown pattern "${pattern}". Known patterns: ${PATTERNS.map((p) => p.id).join(', ')}.`,
          );
        }
        const structured = {
          netKitVersion: kb.version,
          id: found.id,
          title: found.title,
          summary: found.summary,
          recommendedApis: found.symbols.map((name) => ({
            name,
            signature: kb.symbol(name)?.signature ?? '',
            resource: apiUri(name),
          })),
          why: [...found.why],
          security: [...found.security],
          example: found.example,
          resources: [...found.resources],
        };
        const text = [
          `${found.title} (net_kit ${kb.version})`,
          found.summary,
          '',
          ...found.why.map((w) => `- ${w}`),
          '',
          'Security:',
          ...found.security.map((s) => `- ${s}`),
          '',
          '```dart',
          found.example,
          '```',
        ].join('\n');
        return ok(text, structured);
      } catch (error) {
        return errorResult(error, logger, 'explain_netkit_pattern');
      }
    },
  );

  server.registerTool(
    'recommend_netkit_pattern',
    {
      title: 'Recommend net_kit building blocks',
      description:
        'Given requirements (destination, authentication, body source and size, replay, streaming, cancellation, progress) returns the net_kit client, call, auth policy, body type, and the reasoning behind each choice. Deterministic.',
      inputSchema: z.object({
        destination: z.enum(['api', 'external']).optional(),
        externalUrl: z.boolean().optional(),
        authenticated: z.boolean().optional(),
        publicEndpoint: z.boolean().optional(),
        bodySource: z.enum(['none', 'json', 'bytes', 'file', 'stream', 'multipart']).optional(),
        largeRequestBody: z.boolean().optional(),
        requiresReplay: z.boolean().optional(),
        httpMethod: z.enum(['GET', 'POST', 'PUT', 'PATCH', 'DELETE']).optional(),
        streamResponse: z.boolean().optional(),
        needsCancellation: z.boolean().optional(),
        needsProgress: z.boolean().optional(),
      }),
      outputSchema: z.object({
        netKitVersion: z.string(),
        client: z.string(),
        call: z.string(),
        authPolicy: z.string().nullable(),
        requestBody: z.string().nullable(),
        responseHandling: z.string(),
        options: z.array(z.string()),
        reasoning: z.array(z.object({ rule: z.string(), conclusion: z.string() })),
        warnings: z.array(z.string()),
        patterns: z.array(z.string()),
        resources: z.array(z.string()),
      }),
      annotations: ANNOTATIONS,
    },
    (input) => {
      try {
        const kb = knowledge();
        const result = recommend(input);
        const structured = {
          netKitVersion: kb.version,
          ...result,
          options: [...result.options],
          reasoning: result.reasoning.map((r) => ({ ...r })),
          warnings: [...result.warnings],
          patterns: [...result.patterns],
          resources: [...result.resources],
        };
        const text = [
          `Use ${result.client}: ${result.call}`,
          result.authPolicy === null ? '' : `Auth policy: ${result.authPolicy}`,
          result.requestBody === null ? '' : `Body: ${result.requestBody}`,
          `Response: ${result.responseHandling}`,
          ...result.warnings.map((w) => `Warning: ${w}`),
        ]
          .filter((line) => line !== '')
          .join('\n');
        return ok(text, structured);
      } catch (error) {
        return errorResult(error, logger, 'recommend_netkit_pattern');
      }
    },
  );
}
