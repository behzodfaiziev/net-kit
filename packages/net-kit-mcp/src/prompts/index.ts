import type { GetPromptResult, McpServer } from '@modelcontextprotocol/server';
import * as z from 'zod/v4';

/**
 * Prompts compose the tools and resources; they carry no knowledge of their
 * own beyond the order of steps. Every prompt ends by asking for suggestions
 * as text: the server never edits files.
 */

const READ_ONLY_CLOSING =
  'Do not edit files. Present every change as a suggestion (code snippet or diff-like text) for the user to apply, and cite the netkit:// resources behind each recommendation.';

function message(text: string): GetPromptResult {
  return { messages: [{ role: 'user', content: { type: 'text', text } }] };
}

const rootArg = { root: z.string().max(256).optional().describe('Authorized root id or name.') };

export function registerPrompts(server: McpServer, includeWorkspace: boolean): void {
  if (includeWorkspace) {
    server.registerPrompt(
      'review-netkit-network-layer',
      {
        title: 'Review the net_kit network layer',
        description:
          "Full review of a project's net_kit usage: version, configuration, auth, refresh, external URLs, uploads, streaming.",
        argsSchema: z.object(rootArg),
      },
      ({ root }) =>
        message(
          [
            `Review the net_kit network layer of the project${root === undefined ? '' : ` in root "${root}"`}.`,
            '',
            '1. Read netkit://overview and netkit://version for the net_kit version the knowledge describes.',
            '2. Call validate_netkit_configuration to inventory NetKitManager setups.',
            '3. Call review_auth_flow, then review_refresh_flow. Keep the session rule in mind: only a refresh-endpoint 401 ends a session.',
            '4. Call review_upload_flow and review_streaming_usage; distinguish authenticated API uploads from external signed-URL uploads.',
            '5. If the project still uses 5.x APIs, call check_v5_to_v6_migration.',
            '6. Return a prioritized list: errors, then high-confidence warnings, then the rest. Treat medium/low confidence findings as review hints, and say so.',
            '',
            READ_ONLY_CLOSING,
          ].join('\n'),
        ),
    );

    server.registerPrompt(
      'review-netkit-auth',
      {
        title: 'Review net_kit authentication',
        description:
          'Focused review of AuthPolicy usage, token handling, refresh, and sign-out logic.',
        argsSchema: z.object(rootArg),
      },
      ({ root }) =>
        message(
          [
            `Review authentication in the project${root === undefined ? '' : ` in root "${root}"`}.`,
            '',
            '1. Read netkit://docs/auth.when-the-session-ends-and-when-it-does-not and netkit://api/AuthPolicy.',
            '2. Call review_auth_flow and review_refresh_flow.',
            '3. For each finding, explain the user-visible consequence (for example: signed out while offline, token sent to a storage host).',
            '4. Confirm public endpoints use AuthPolicy.none and that sign-out happens only in onSessionInvalidated or on ApiFailureType.sessionInvalidated.',
            '',
            READ_ONLY_CLOSING,
          ].join('\n'),
        ),
    );

    server.registerPrompt(
      'migrate-netkit-v5-to-v6',
      {
        title: 'Plan a net_kit 5.x → 6 migration',
        description:
          'Builds a project-specific migration plan from detected 5.x usage and the migration guide.',
        argsSchema: z.object(rootArg),
      },
      ({ root }) =>
        message(
          [
            `Plan the net_kit 5.x → 6 migration for the project${root === undefined ? '' : ` in root "${root}"`}.`,
            '',
            '1. Call check_v5_to_v6_migration.',
            '2. Read netkit://docs/migration.breaking-change-ledger and the entries cited by each checklist item.',
            '3. Order the plan: compile-breaking changes first, then behavioral changes (auth flags → AuthPolicy, onRefreshFailed → onSessionInvalidated, origin policy), then the manual checks.',
            '4. For each step, show a before/after snippet for this project.',
            '',
            READ_ONLY_CLOSING,
          ].join('\n'),
        ),
    );
  }

  server.registerPrompt(
    'design-netkit-upload',
    {
      title: 'Design an upload with net_kit',
      description: 'Designs an upload (API or signed external URL) using current net_kit APIs.',
      argsSchema: z.object({
        destination: z.string().max(200).optional().describe('"api" or "signed external URL".'),
        expectedSize: z.string().max(100).optional(),
        authenticated: z.string().max(20).optional(),
        retry: z.string().max(200).optional(),
        cancellation: z.string().max(20).optional(),
        progress: z.string().max(20).optional(),
        concurrency: z.string().max(200).optional(),
      }),
    },
    (args) =>
      message(
        [
          'Design an upload with net_kit using these requirements:',
          ...Object.entries(args)
            .filter(([, value]) => value !== '')
            .map(([key, value]) => `- ${key}: ${value}`),
          '',
          '1. Call recommend_netkit_pattern with the matching structured inputs.',
          '2. Call explain_netkit_pattern for each pattern it returns (for example signed-external-upload or replayable-authenticated-upload).',
          '3. Verify signatures with get_netkit_api (NetKitManager, RawHttpRequest, FileRawHttpBody, NetKitMultipartFile, NetKitCancellationToken).',
          '4. Produce the architecture: which client sends what, body type, memory behavior, replay after token refresh, cancellation, progress, and failure handling.',
          '',
          READ_ONLY_CLOSING,
        ].join('\n'),
      ),
  );

  server.registerPrompt(
    'design-netkit-streaming',
    {
      title: 'Design streaming with net_kit',
      description:
        'Designs a streamed download or streamed request body using current net_kit APIs.',
      argsSchema: z.object({
        direction: z.string().max(100).optional().describe('"download", "upload", or both.'),
        expectedSize: z.string().max(100).optional(),
        source: z.string().max(200).optional().describe('Where the data comes from or goes to.'),
        authenticated: z.string().max(20).optional(),
      }),
    },
    (args) =>
      message(
        [
          'Design streaming with net_kit using these requirements:',
          ...Object.entries(args)
            .filter(([, value]) => value !== '')
            .map(([key, value]) => `- ${key}: ${value}`),
          '',
          '1. Read netkit://docs/streaming.',
          '2. Call recommend_netkit_pattern (set streamResponse / bodySource accordingly) and explain_netkit_pattern for streaming-download.',
          '3. Check get_netkit_api for RawHttpStreamedResponse, ReplayableRawHttpBody, StreamRawHttpBody, and FileRawHttpBody.',
          '4. Explain memory behavior, back-pressure, replayability, and cancellation for the design.',
          '',
          READ_ONLY_CLOSING,
        ].join('\n'),
      ),
  );
}
