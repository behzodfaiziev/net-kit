import {
  ResourceNotFoundError,
  ResourceTemplate,
  type McpServer,
} from '@modelcontextprotocol/server';

import { RULE_CATALOG } from '../analyzer/rules/index.js';
import { apiUri, docUri, type KnowledgeBase } from '../knowledge/knowledgeBase.js';
import {
  renderApiIndex,
  renderDoc,
  renderDocsIndex,
  renderSection,
  renderSymbol,
} from '../knowledge/render.js';
import { PATTERNS } from '../patterns/catalog.js';

/**
 * Knowledge resources (capability group `knowledge`).
 *
 * URIs: netkit://overview, netkit://version, netkit://rules,
 * netkit://api/index, netkit://api/{symbol}, netkit://docs/index,
 * netkit://docs/{section} where section is a document id (readme, auth,
 * migration, examples, changelog), a section id such as
 * `auth.when-the-session-ends-and-when-it-does-not`, or the topic `streaming`.
 */

const STREAMING_TOPIC = [
  'readme.large-file-uploads',
  'readme.streaming-responses',
  'readme.cancellation-and-progress',
];

function text(uri: string, mimeType: string, body: string) {
  return { contents: [{ uri, mimeType, text: body }] };
}

function overview(kb: KnowledgeBase): string {
  return [
    '# net_kit overview',
    '',
    `net_kit version: ${kb.version}`,
    '',
    'net_kit is a Dart/Flutter networking package. Its public API is transport-neutral:',
    '',
    '- `NetKitManager` is the API client: base URL and stored headers, JSON decoding into `INetKitModel`, `AuthPolicy` per request, single-flight token refresh with one retry, origin and redirect policy, interceptors, and typed `ApiException` errors.',
    '- `NetKitTransport` / `RawHttpClient` is the raw client for absolute URLs (for example signed storage uploads): exact headers, no credentials, no refresh, every status returned, streamed request bodies and streamed responses.',
    '- `DioNetKitTransport` (in `package:net_kit/net_kit_dio.dart`) is the default transport adapter.',
    '',
    'Session rule: only the refresh endpoint answering HTTP 401 ends a session (`onSessionInvalidated`, `ApiFailureType.sessionInvalidated`). Offline, timeouts, 5xx, and other refresh failures keep it.',
    '',
    '## Entrypoints',
    ...kb.artifact.entrypoints.map((e) => `- \`${e.uri}\`: ${e.description}`),
    '',
    '## Resources',
    '- netkit://version, netkit://rules',
    '- netkit://api/index and netkit://api/{symbol}',
    '- netkit://docs/index and netkit://docs/{document-or-section}; topic: netkit://docs/streaming',
    '',
    '## Patterns (explain_netkit_pattern)',
    ...PATTERNS.map((p) => `- ${p.id}: ${p.summary}`),
  ].join('\n');
}

export function registerResources(server: McpServer, knowledge: () => KnowledgeBase): void {
  server.registerResource(
    'netkit-overview',
    'netkit://overview',
    {
      title: 'net_kit overview',
      description: 'Architecture summary, entrypoints, and resource map.',
      mimeType: 'text/markdown',
    },
    (uri) => text(uri.href, 'text/markdown', overview(knowledge())),
  );

  server.registerResource(
    'netkit-version',
    'netkit://version',
    {
      title: 'net_kit version',
      description: 'Version of net_kit the knowledge was generated from.',
      mimeType: 'application/json',
    },
    (uri) => {
      const kb = knowledge();
      return text(
        uri.href,
        'application/json',
        JSON.stringify(
          {
            package: kb.artifact.netKit.package,
            version: kb.version,
            sdkConstraint: kb.artifact.netKit.sdkConstraint,
            dependencies: kb.artifact.netKit.dependencies,
            migrationCoverage: '5.x → 6.0',
          },
          null,
          2,
        ),
      );
    },
  );

  server.registerResource(
    'netkit-rules',
    'netkit://rules',
    {
      title: 'Semantic rules',
      description: 'The NK rules the project analyzer applies.',
      mimeType: 'application/json',
    },
    (uri) =>
      text(
        uri.href,
        'application/json',
        JSON.stringify({ netKitVersion: knowledge().version, rules: RULE_CATALOG }, null, 2),
      ),
  );

  server.registerResource(
    'netkit-api-index',
    'netkit://api/index',
    {
      title: 'net_kit API index',
      description: 'Every public symbol, its kind and entrypoints.',
      mimeType: 'application/json',
    },
    (uri) => text(uri.href, 'application/json', renderApiIndex(knowledge())),
  );

  server.registerResource(
    'netkit-docs-index',
    'netkit://docs/index',
    {
      title: 'net_kit documentation index',
      description: 'Documents and section ids.',
      mimeType: 'application/json',
    },
    (uri) => text(uri.href, 'application/json', renderDocsIndex(knowledge())),
  );

  server.registerResource(
    'netkit-api-symbol',
    new ResourceTemplate('netkit://api/{symbol}', {
      list: () => ({
        resources: knowledge().symbols.map((s) => ({
          uri: apiUri(s.name),
          name: s.name,
          title: `${s.kind} ${s.name}`,
          mimeType: 'text/markdown',
        })),
      }),
    }),
    {
      title: 'net_kit public symbol',
      description: 'Source-derived declaration, members, and Dartdoc.',
      mimeType: 'text/markdown',
    },
    (uri, variables) => {
      const kb = knowledge();
      const raw = variables.symbol;
      const name = decodeURIComponent(Array.isArray(raw) ? (raw[0] ?? '') : (raw ?? ''));
      if (name === 'index') {
        return text(uri.href, 'application/json', renderApiIndex(kb));
      }
      const symbol = kb.symbol(name);
      if (symbol === undefined) {
        throw new ResourceNotFoundError(uri.href, `No public net_kit symbol named "${name}".`);
      }
      return text(uri.href, 'text/markdown', renderSymbol(kb, symbol));
    },
  );

  server.registerResource(
    'netkit-docs',
    new ResourceTemplate('netkit://docs/{section}', {
      list: () => ({
        resources: [
          ...knowledge().docs.map((d) => ({
            uri: docUri(d.id),
            name: d.id,
            title: d.title,
            mimeType: 'text/markdown',
          })),
          {
            uri: docUri('streaming'),
            name: 'streaming',
            title: 'Streaming uploads and downloads',
            mimeType: 'text/markdown',
          },
        ],
      }),
    }),
    {
      title: 'net_kit documentation',
      description: 'A document, one of its sections, or a topic.',
      mimeType: 'text/markdown',
    },
    (uri, variables) => {
      const kb = knowledge();
      const raw = variables.section;
      const id = decodeURIComponent(Array.isArray(raw) ? (raw[0] ?? '') : (raw ?? ''));
      if (id === 'index') {
        return text(uri.href, 'application/json', renderDocsIndex(kb));
      }
      if (id === 'streaming') {
        const parts = STREAMING_TOPIC.map((sid) => kb.section(sid))
          .filter((s) => s !== undefined)
          .map((s) => renderSection(kb, s.doc, s.section));
        return text(uri.href, 'text/markdown', parts.join('\n\n---\n\n'));
      }
      const doc = kb.doc(id);
      if (doc !== undefined) {
        return text(uri.href, 'text/markdown', renderDoc(kb, doc));
      }
      const section = kb.section(id);
      if (section !== undefined) {
        return text(uri.href, 'text/markdown', renderSection(kb, section.doc, section.section));
      }
      throw new ResourceNotFoundError(
        uri.href,
        `No net_kit document or section "${id}". See netkit://docs/index.`,
      );
    },
  );
}
