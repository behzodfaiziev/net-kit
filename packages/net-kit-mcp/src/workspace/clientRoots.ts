import { fileURLToPath } from 'node:url';

import { WorkspaceError } from './errors.js';
import { authorizeRoots, type AuthorizedRoot } from './roots.js';

export interface ClientRootEntry {
  readonly uri: string;
  readonly name?: string | undefined;
}

export interface ClientRootResult {
  readonly roots: AuthorizedRoot[];
  /** Roots the client offered that were refused, by name and reason (no paths). */
  readonly rejected: { readonly name: string; readonly reason: string }[];
}

/**
 * Converts roots offered by the MCP client into authorized roots.
 *
 * Only `file://` URIs are accepted. Each root is validated on its own: a
 * missing directory, a non-directory, or a too-broad root (filesystem or
 * home directory) is refused without affecting the others.
 */
export function authorizeClientRoots(entries: readonly ClientRootEntry[]): ClientRootResult {
  const accepted: { path: string; name?: string }[] = [];
  const rejected: { name: string; reason: string }[] = [];
  entries.forEach((entry, index) => {
    const name = entry.name ?? `client root ${index + 1}`;
    if (!entry.uri.startsWith('file://')) {
      rejected.push({ name, reason: 'not a file:// URI' });
      return;
    }
    let path: string;
    try {
      path = fileURLToPath(entry.uri);
    } catch {
      rejected.push({ name, reason: 'malformed file URI' });
      return;
    }
    try {
      authorizeRoots([{ path, ...(entry.name === undefined ? {} : { name: entry.name }) }]);
      accepted.push({ path, ...(entry.name === undefined ? {} : { name: entry.name }) });
    } catch (error) {
      rejected.push({ name, reason: error instanceof WorkspaceError ? error.code : 'invalid' });
    }
  });
  return { roots: authorizeRoots(accepted), rejected };
}
