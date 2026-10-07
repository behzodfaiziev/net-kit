import * as z from 'zod/v4';

/** Shared structured-output schemas. */

export const rangeSchema = z.object({
  startLine: z.number(),
  startColumn: z.number(),
  endLine: z.number(),
  endColumn: z.number(),
});

export const suggestionSchema = z.object({
  label: z.literal('SUGGESTED — NOT APPLIED'),
  currentPattern: z.string(),
  suggestedPattern: z.string(),
  explanation: z.string(),
});

export const findingSchema = z.object({
  ruleId: z.string(),
  title: z.string(),
  severity: z.enum(['info', 'warning', 'error']),
  confidence: z.enum(['high', 'medium', 'low']),
  file: z.string(),
  range: rangeSchema,
  message: z.string(),
  recommendation: z.string(),
  resources: z.array(z.string()),
  suggestion: suggestionSchema.optional(),
});

export const rootRefSchema = z.object({ id: z.string(), name: z.string() });

export const projectSchema = z.object({
  root: rootRefSchema,
  netKitConstraint: z.string().nullable(),
  resolvedNetKitVersion: z.string().nullable(),
  targetMajor: z.number().nullable(),
  apiHosts: z.array(z.string()),
});

export const statsSchema = z.object({
  scopes: z.array(z.string()),
  filesDiscovered: z.number(),
  filesAnalyzed: z.number(),
  bytesRead: z.number(),
  skippedFiles: z.number(),
  skippedSensitiveFiles: z.number(),
  skippedSymlinks: z.number(),
  truncated: z.boolean(),
  diagnosticsTruncated: z.boolean(),
});

export const analysisOutputSchema = z.object({
  netKitVersion: z.string(),
  tool: z.string(),
  summary: z.string(),
  project: projectSchema,
  findings: z.array(findingSchema),
  stats: statsSchema,
  notes: z.array(z.string()),
  readOnly: z.literal(true),
  sourceExcerptsAreUntrusted: z.literal(true),
});

/** Input shared by every workspace tool. */
export const workspaceInput = {
  root: z
    .string()
    .max(256)
    .optional()
    .describe(
      'Authorized root id or name (see list_workspace_roots). Optional when exactly one root is authorized.',
    ),
  paths: z
    .array(z.string().min(1).max(512))
    .max(50)
    .optional()
    .describe(
      'Root-relative files or directories to analyze. Defaults to lib/ (or the root when there is no lib/).',
    ),
};
