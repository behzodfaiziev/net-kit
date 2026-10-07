import {
  closeSync,
  constants,
  fstatSync,
  openSync,
  readdirSync,
  readSync,
  statSync,
} from 'node:fs';
import { join } from 'node:path';

import { quoteInput, WorkspaceError } from './errors.js';
import type { WorkspaceLimits } from './limits.js';
import { resolveInRoot, type ResolvedPath } from './pathGuard.js';
import { isExcludedDirectory, isSensitiveFileName, readableReason } from './policy.js';
import type { AuthorizedRoot } from './roots.js';

/**
 * Read-only access to one authorized root for the duration of one request.
 *
 * Every path goes through `resolveInRoot`; files are opened read-only and
 * without following a final symbolic link; budgets cap the number of files
 * and bytes. Contents live only in memory for the request. There is no
 * write, rename, delete, or execute operation anywhere in this layer.
 *
 * File contents are data. Nothing read here can change which root is used,
 * which paths are allowed, or any server setting.
 */
export class WorkspaceSession {
  private filesRead = 0;
  private bytesRead = 0;
  private readonly readLog: string[] = [];
  private skippedSensitive = 0;
  private skippedSymlinks = 0;
  truncated = false;

  constructor(
    readonly root: AuthorizedRoot,
    readonly limits: WorkspaceLimits,
  ) {}

  /** Root-relative paths read so far, in order. */
  get reads(): readonly string[] {
    return this.readLog;
  }

  get stats(): {
    filesRead: number;
    bytesRead: number;
    skippedSensitiveFiles: number;
    skippedSymlinks: number;
    truncated: boolean;
  } {
    return {
      filesRead: this.filesRead,
      bytesRead: this.bytesRead,
      skippedSensitiveFiles: this.skippedSensitive,
      skippedSymlinks: this.skippedSymlinks,
      truncated: this.truncated,
    };
  }

  /** Resolves a caller-supplied path inside the root. */
  resolve(
    requested: string,
    options?: { allowDirectory?: boolean; allowLockFile?: boolean },
  ): ResolvedPath {
    return resolveInRoot(this.root, requested, options);
  }

  /**
   * Reads a text file. Throws [WorkspaceError] for policy violations,
   * oversized or binary files, and exhausted budgets.
   */
  readText(requested: string, options: { allowLockFile?: boolean } = {}): string {
    const resolved = this.resolve(requested, { allowLockFile: options.allowLockFile === true });
    if (this.filesRead >= this.limits.maxFiles) {
      this.truncated = true;
      throw new WorkspaceError('limit_exceeded', `File limit (${this.limits.maxFiles}) reached.`);
    }
    const noFollow = constants.O_NOFOLLOW;
    let fd: number;
    try {
      fd = openSync(resolved.realPath, constants.O_RDONLY | noFollow);
    } catch {
      throw new WorkspaceError(
        'not_found',
        `File ${quoteInput(resolved.relativePath)} could not be opened.`,
      );
    }
    try {
      const stat = fstatSync(fd);
      if (!stat.isFile()) {
        throw new WorkspaceError(
          'unsupported_file',
          `${quoteInput(resolved.relativePath)} is not a regular file.`,
        );
      }
      // A hard link can expose a file from outside the root under an
      // innocent name; canonical paths cannot reveal it, so refuse them.
      if (stat.nlink > 1) {
        throw new WorkspaceError(
          'unsupported_file',
          `File ${quoteInput(resolved.relativePath)} has multiple hard links and is not read.`,
        );
      }
      if (stat.size > this.limits.maxFileBytes) {
        throw new WorkspaceError(
          'file_too_large',
          `File ${quoteInput(resolved.relativePath)} is larger than ${this.limits.maxFileBytes} bytes.`,
        );
      }
      if (this.bytesRead + stat.size > this.limits.maxTotalBytes) {
        this.truncated = true;
        throw new WorkspaceError(
          'limit_exceeded',
          `Byte budget (${this.limits.maxTotalBytes}) reached.`,
        );
      }
      const buffer = Buffer.alloc(stat.size);
      let offset = 0;
      while (offset < stat.size) {
        const read = readSync(fd, buffer, offset, stat.size - offset, offset);
        if (read === 0) break;
        offset += read;
      }
      const content = buffer.subarray(0, offset);
      if (content.subarray(0, 8000).includes(0)) {
        throw new WorkspaceError(
          'binary_file',
          `File ${quoteInput(resolved.relativePath)} is binary.`,
        );
      }
      this.filesRead++;
      this.bytesRead += offset;
      this.readLog.push(resolved.relativePath);
      return content.toString('utf8');
    } finally {
      closeSync(fd);
    }
  }

  /** Reads a file if it exists and is readable; `null` otherwise. */
  tryReadText(requested: string, options: { allowLockFile?: boolean } = {}): string | null {
    try {
      return this.readText(requested, options);
    } catch (error) {
      if (error instanceof WorkspaceError && error.code !== 'limit_exceeded') {
        return null;
      }
      throw error;
    }
  }

  /**
   * Lists analyzable files under [scopes] (root-relative files or
   * directories). Symbolic links are not followed during discovery,
   * excluded directories are not entered, and sensitive files are skipped.
   */
  discover(scopes: readonly string[], accept: (relativePath: string) => boolean): string[] {
    const found = new Set<string>();
    let visited = 0;
    for (const scope of scopes) {
      const resolved = this.resolve(scope, { allowDirectory: true });
      if (!statSync(resolved.realPath).isDirectory()) {
        if (accept(resolved.relativePath)) found.add(resolved.relativePath);
        continue;
      }
      const queue: { real: string; rel: string; depth: number }[] = [
        {
          real: resolved.realPath,
          rel: resolved.relativePath === '.' ? '' : resolved.relativePath,
          depth: 0,
        },
      ];
      while (queue.length > 0) {
        const dir = queue.shift();
        if (dir === undefined) break;
        let entries;
        try {
          entries = readdirSync(dir.real, { withFileTypes: true });
        } catch {
          continue;
        }
        entries.sort((a, b) => a.name.localeCompare(b.name));
        for (const entry of entries) {
          if (++visited > this.limits.maxWalkEntries) {
            this.truncated = true;
            return [...found];
          }
          const rel = dir.rel === '' ? entry.name : `${dir.rel}/${entry.name}`;
          if (entry.isSymbolicLink()) {
            this.skippedSymlinks++;
            continue;
          }
          if (entry.isDirectory()) {
            if (isExcludedDirectory(entry.name) || entry.name.startsWith('.')) continue;
            if (dir.depth + 1 > this.limits.maxDepth) {
              this.truncated = true;
              continue;
            }
            queue.push({ real: join(dir.real, entry.name), rel, depth: dir.depth + 1 });
            continue;
          }
          if (!entry.isFile()) continue;
          if (isSensitiveFileName(entry.name)) {
            this.skippedSensitive++;
            continue;
          }
          if (readableReason(rel, false) === 'ok' && accept(rel)) {
            found.add(rel);
          }
        }
      }
    }
    return [...found].sort();
  }
}
