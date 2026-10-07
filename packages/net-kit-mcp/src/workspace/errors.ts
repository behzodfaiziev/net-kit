/**
 * Errors raised by the workspace layer.
 *
 * Messages never contain absolute paths: they mention only root ids/names
 * and paths relative to an authorized root (or the caller's own input).
 */
export type WorkspaceErrorCode =
  | 'no_authorized_root'
  | 'unknown_root'
  | 'ambiguous_root'
  | 'invalid_root'
  | 'root_too_broad'
  | 'invalid_path'
  | 'path_escape'
  | 'excluded_path'
  | 'sensitive_file'
  | 'unsupported_file'
  | 'binary_file'
  | 'file_too_large'
  | 'not_found'
  | 'limit_exceeded';

export class WorkspaceError extends Error {
  constructor(
    readonly code: WorkspaceErrorCode,
    message: string,
  ) {
    super(message);
    this.name = 'WorkspaceError';
  }
}

/**
 * Quotes a caller-supplied path for an error message. Absolute paths are
 * never echoed: they could reveal machine-specific directories.
 */
export function quotePath(value: string): string {
  if (value.startsWith('/') || /^[A-Za-z]:[\\/]/.test(value) || value.startsWith('\\\\')) {
    return '"<absolute path>"';
  }
  return quoteInput(value);
}

/** Quotes caller input for an error message, truncated and without control characters. */
export function quoteInput(value: string): string {
  // eslint-disable-next-line no-control-regex
  const clean = value.replace(/[\u0000-\u001f\u007f]/g, '?');
  return JSON.stringify(clean.length > 120 ? `${clean.slice(0, 120)}…` : clean);
}
