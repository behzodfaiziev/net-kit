import { realpathSync, statSync } from 'node:fs';
import { isAbsolute, relative, resolve, sep } from 'node:path';

import { quotePath, WorkspaceError } from './errors.js';
import { isExcludedDirectory, readableReason } from './policy.js';
import type { AuthorizedRoot } from './roots.js';

/**
 * The only way the server turns caller input into a filesystem path.
 *
 * Every project read goes through [resolveInRoot]. It accepts a path
 * relative to an authorized root (or an absolute path that is inside it),
 * rejects anything that leaves the root lexically or through symlinks, and
 * applies the read policy to the canonical root-relative path.
 */

export interface ResolvedPath {
  readonly root: AuthorizedRoot;
  /** Canonical path relative to the root, with `/` separators. */
  readonly relativePath: string;
  /** Canonical absolute path. Internal only; never returned to clients. */
  readonly realPath: string;
}

const MAX_INPUT_LENGTH = 1024;

/** Whether [target] is [base] or inside it. Both must be canonical. */
export function isWithin(base: string, target: string): boolean {
  const rel = relative(base, target);
  return rel === '' || (!rel.startsWith(`..${sep}`) && rel !== '..' && !isAbsolute(rel));
}

function toPosix(path: string): string {
  return path.split(sep).join('/');
}

export interface ResolveOptions {
  /** Accept a directory (for discovery scopes). Files are always accepted. */
  readonly allowDirectory?: boolean;
  /** Allow `pubspec.lock` (dependency version inspection only). */
  readonly allowLockFile?: boolean;
}

export function resolveInRoot(
  root: AuthorizedRoot,
  requested: string,
  options: ResolveOptions = {},
): ResolvedPath {
  if (typeof requested !== 'string' || requested.length === 0) {
    throw new WorkspaceError('invalid_path', 'A non-empty relative path is required.');
  }
  if (requested.length > MAX_INPUT_LENGTH || requested.includes('\0')) {
    throw new WorkspaceError('invalid_path', `Path ${quotePath(requested)} is not valid.`);
  }
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(requested)) {
    throw new WorkspaceError(
      'invalid_path',
      `Path ${quotePath(requested)} is a URI; pass a path relative to the root.`,
    );
  }

  const lexical = resolve(root.realPath, requested);
  if (!isWithin(root.realPath, lexical)) {
    throw new WorkspaceError(
      'path_escape',
      `Path ${quotePath(requested)} is outside root ${root.id}.`,
    );
  }

  let realPath: string;
  try {
    realPath = realpathSync.native(lexical);
  } catch {
    throw new WorkspaceError(
      'not_found',
      `Path ${quotePath(requested)} was not found in root ${root.id}.`,
    );
  }
  if (!isWithin(root.realPath, realPath)) {
    throw new WorkspaceError(
      'path_escape',
      `Path ${quotePath(requested)} resolves outside root ${root.id} (symbolic link).`,
    );
  }

  const relativePath = toPosix(relative(root.realPath, realPath));
  if (relativePath === '') {
    if (options.allowDirectory === true) {
      return { root, relativePath: '.', realPath };
    }
    throw new WorkspaceError('invalid_path', 'The root itself is not a file.');
  }

  if (statSync(realPath).isDirectory()) {
    if (options.allowDirectory !== true) {
      throw new WorkspaceError('invalid_path', `Path ${quotePath(relativePath)} is a directory.`);
    }
    if (relativePath.split('/').some((segment) => isExcludedDirectory(segment))) {
      throw new WorkspaceError(
        'excluded_path',
        `Path ${quotePath(relativePath)} is an excluded directory.`,
      );
    }
    return { root, relativePath, realPath };
  }

  const reason = readableReason(relativePath, options.allowLockFile === true);
  if (reason === 'excluded_path' || reason === 'sensitive_file') {
    throw new WorkspaceError(
      reason,
      reason === 'sensitive_file'
        ? `File ${quotePath(relativePath)} looks like it holds secrets and is never read.`
        : `Path ${quotePath(relativePath)} is inside an excluded directory.`,
    );
  }
  if (reason === 'unsupported_file') {
    throw new WorkspaceError(
      'unsupported_file',
      `File ${quotePath(relativePath)} is not an analyzable text file.`,
    );
  }
  return { root, relativePath, realPath };
}
