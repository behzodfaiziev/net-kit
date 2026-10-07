import { realpathSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, parse, resolve } from 'node:path';

import { quoteInput, WorkspaceError } from './errors.js';

/**
 * A directory the MCP client (or the operator, at startup) authorized for
 * read-only inspection. `realPath` is internal: it is never returned to
 * clients; tools refer to roots by `id` and `name`.
 */
export interface AuthorizedRoot {
  readonly id: string;
  readonly name: string;
  readonly realPath: string;
}

export interface RootCandidate {
  readonly path: string;
  readonly name?: string;
}

/**
 * Validates and canonicalizes root candidates.
 *
 * A root must be an existing directory. The filesystem root and the user's
 * home directory itself are refused as too broad; a project directory inside
 * the home directory is fine.
 */
export function authorizeRoots(candidates: readonly RootCandidate[]): AuthorizedRoot[] {
  const roots: AuthorizedRoot[] = [];
  const seen = new Set<string>();
  candidates.forEach((candidate, index) => {
    const label = candidate.name ?? `root ${index + 1}`;
    let realPath: string;
    try {
      realPath = realpathSync.native(resolve(candidate.path));
    } catch {
      throw new WorkspaceError('invalid_root', `Root ${quoteInput(label)} does not exist.`);
    }
    if (!statSync(realPath).isDirectory()) {
      throw new WorkspaceError('invalid_root', `Root ${quoteInput(label)} is not a directory.`);
    }
    if (isTooBroad(realPath)) {
      throw new WorkspaceError(
        'root_too_broad',
        `Root ${quoteInput(label)} is a filesystem or home directory root; authorize a project directory instead.`,
      );
    }
    if (seen.has(realPath)) {
      return;
    }
    seen.add(realPath);
    roots.push({
      id: `root${roots.length + 1}`,
      name: candidate.name ?? basename(realPath),
      realPath,
    });
  });
  return roots;
}

function isTooBroad(realPath: string): boolean {
  if (parse(realPath).root === realPath) {
    return true;
  }
  try {
    return realpathSync.native(homedir()) === realPath;
  } catch {
    return false;
  }
}

/**
 * Selects the root a request targets. With one root the selector is
 * optional; with several it must name one by id or name.
 */
export function selectRoot(
  roots: readonly AuthorizedRoot[],
  selector: string | undefined,
): AuthorizedRoot {
  if (roots.length === 0) {
    throw new WorkspaceError(
      'no_authorized_root',
      'No workspace root is authorized. Start the server with --root <dir> or use an MCP client that provides roots.',
    );
  }
  if (selector === undefined || selector === '') {
    if (roots.length === 1 && roots[0] !== undefined) {
      return roots[0];
    }
    throw new WorkspaceError(
      'ambiguous_root',
      `Several roots are authorized (${roots.map((r) => `${r.id}: ${r.name}`).join(', ')}); pass "root".`,
    );
  }
  const match = roots.find((r) => r.id === selector) ?? roots.find((r) => r.name === selector);
  if (match === undefined) {
    throw new WorkspaceError(
      'unknown_root',
      `Root ${quoteInput(selector)} is not authorized. Authorized roots: ${roots
        .map((r) => `${r.id}: ${r.name}`)
        .join(', ')}.`,
    );
  }
  return match;
}
