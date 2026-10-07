import {
  CLIENT_CAPABILITIES_META_KEY,
  inputRequired,
  type InputRequiredResult,
  type McpServer,
  type ServerContext,
} from '@modelcontextprotocol/server';
import * as z from 'zod/v4';

import { authorizeClientRoots } from '../workspace/clientRoots.js';
import { WorkspaceError } from '../workspace/errors.js';
import type { AuthorizedRoot } from '../workspace/roots.js';

/**
 * Where workspace authorization comes from.
 *
 * - `startup`: roots passed to the server on the command line. When present
 *   they are the only roots; client roots are not consulted.
 * - `client`: roots the MCP client provides for each request. On the
 *   2026-07-28 protocol they are requested with an `input_required` result;
 *   on earlier protocol versions the SDK performs the `roots/list` request.
 *
 * Nothing else — the process working directory, environment variables,
 * parent or sibling directories, or anything found in project files — can
 * authorize a path.
 */
export type RootPolicy =
  | { readonly mode: 'startup'; readonly roots: readonly AuthorizedRoot[] }
  | { readonly mode: 'client' };

export type RootAcquisition =
  | {
      readonly kind: 'roots';
      readonly roots: readonly AuthorizedRoot[];
      readonly notes: readonly string[];
    }
  | { readonly kind: 'input'; readonly result: InputRequiredResult };

const ROOTS_REQUEST_KEY = 'netkit_roots';

const listRootsResultSchema = z.object({
  roots: z
    .array(z.object({ uri: z.string().max(4096), name: z.string().max(256).optional() }))
    .max(64),
});

function clientSupportsRoots(ctx: ServerContext, server: McpServer): boolean {
  const envelope = ctx.mcpReq.envelope as Record<string, unknown> | undefined;
  const perRequest = envelope?.[CLIENT_CAPABILITIES_META_KEY] as { roots?: unknown } | undefined;
  if (perRequest !== undefined) {
    return perRequest.roots !== undefined;
  }
  // 2025-era connections declare capabilities once, in `initialize`; the
  // SDK marks this accessor deprecated in favor of the per-request envelope
  // read above, which 2025-era requests do not carry.
  // eslint-disable-next-line @typescript-eslint/no-deprecated
  return server.server.getClientCapabilities()?.roots !== undefined;
}

export function acquireRoots(
  policy: RootPolicy,
  ctx: ServerContext,
  server: McpServer,
): RootAcquisition {
  if (policy.mode === 'startup') {
    return { kind: 'roots', roots: policy.roots, notes: [] };
  }
  const response = ctx.mcpReq.inputResponses?.[ROOTS_REQUEST_KEY];
  if (response !== undefined) {
    const parsed = listRootsResultSchema.safeParse(response);
    if (!parsed.success) {
      throw new WorkspaceError('invalid_root', 'The client returned a malformed roots list.');
    }
    const { roots, rejected } = authorizeClientRoots(parsed.data.roots);
    return {
      kind: 'roots',
      roots,
      notes: rejected.map((r) => `Client root "${r.name}" was not authorized (${r.reason}).`),
    };
  }
  if (!clientSupportsRoots(ctx, server)) {
    throw new WorkspaceError(
      'no_authorized_root',
      'No workspace root is authorized: the client does not provide MCP roots. Start the server with --root <dir> to authorize a project directory.',
    );
  }
  return {
    kind: 'input',
    result: inputRequired({ inputRequests: { [ROOTS_REQUEST_KEY]: inputRequired.listRoots() } }),
  };
}
