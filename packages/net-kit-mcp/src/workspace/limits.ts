/** Resource limits applied to every project-analysis request. */
export interface WorkspaceLimits {
  /** Largest single file read, in bytes. */
  readonly maxFileBytes: number;
  /** Most files read by one request. */
  readonly maxFiles: number;
  /** Most bytes read by one request across all files. */
  readonly maxTotalBytes: number;
  /** Most directory entries visited while discovering files. */
  readonly maxWalkEntries: number;
  /** Deepest directory level visited while discovering files. */
  readonly maxDepth: number;
  /** Most diagnostics returned by one request. */
  readonly maxDiagnostics: number;
}

export const DEFAULT_LIMITS: WorkspaceLimits = {
  maxFileBytes: 512 * 1024,
  maxFiles: 300,
  maxTotalBytes: 6 * 1024 * 1024,
  maxWalkEntries: 5000,
  maxDepth: 16,
  maxDiagnostics: 200,
};
