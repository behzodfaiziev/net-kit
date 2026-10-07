import { basename, extname } from 'node:path';

/**
 * What the workspace layer may read inside an authorized root.
 *
 * Directories that hold VCS data, build output, dependencies, or credentials
 * are never entered. Files that commonly contain secrets are refused even
 * when requested explicitly. Only text formats relevant to net_kit analysis
 * are read at all.
 */

/** Directory names never entered, at any depth. */
export const EXCLUDED_DIRECTORIES: ReadonlySet<string> = new Set([
  '.git',
  '.hg',
  '.svn',
  '.dart_tool',
  '.pub-cache',
  '.fvm',
  '.idea',
  '.gradle',
  '.symlinks',
  '.ssh',
  '.aws',
  '.gnupg',
  '.docker',
  '.kube',
  'build',
  'node_modules',
  'Pods',
  'coverage',
  'ephemeral',
]);

const SENSITIVE_NAME_PATTERNS: readonly RegExp[] = [
  /^\.env$/i,
  /^\.env\..*/i,
  /\.pem$/i,
  /\.key$/i,
  /\.jks$/i,
  /\.keystore$/i,
  /\.p12$/i,
  /\.pfx$/i,
  /\.p8$/i,
  /\.mobileprovision$/i,
  /^id_(rsa|dsa|ecdsa|ed25519)(\.pub)?$/i,
  /^credentials.*/i,
  /^secrets?.*/i,
  /^service[-_]account.*\.json$/i,
  /^google-services\.json$/i,
  /^GoogleService-Info\.plist$/i,
  /^key\.properties$/i,
  /^local\.properties$/i,
  /^\.netrc$/i,
  /^\.npmrc$/i,
  /^\.pypirc$/i,
  /^\.git-credentials$/i,
];

/** Extensions read for analysis. */
const ALLOWED_EXTENSIONS: ReadonlySet<string> = new Set(['.dart', '.yaml', '.yml', '.json', '.md']);

export function isExcludedDirectory(name: string): boolean {
  return EXCLUDED_DIRECTORIES.has(name);
}

export function isSensitiveFileName(name: string): boolean {
  return SENSITIVE_NAME_PATTERNS.some((pattern) => pattern.test(name));
}

/**
 * Whether a root-relative path (posix separators) may be read.
 * `pubspec.lock` is readable only when [allowLockFile] is true.
 */
export function readableReason(
  relativePath: string,
  allowLockFile: boolean,
): 'ok' | 'excluded_path' | 'sensitive_file' | 'unsupported_file' {
  const segments = relativePath.split('/');
  if (segments.slice(0, -1).some((segment) => isExcludedDirectory(segment))) {
    return 'excluded_path';
  }
  const name = basename(relativePath);
  if (isSensitiveFileName(name)) {
    return 'sensitive_file';
  }
  if (name === 'pubspec.lock') {
    return allowLockFile ? 'ok' : 'unsupported_file';
  }
  return ALLOWED_EXTENSIONS.has(extname(name).toLowerCase()) ? 'ok' : 'unsupported_file';
}
