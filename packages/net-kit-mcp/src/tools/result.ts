import type { CallToolResult } from '@modelcontextprotocol/server';

import type { Logger } from '../util/log.js';
import { WorkspaceError } from '../workspace/errors.js';

/** Successful tool result: short human-readable text plus structured content. */
export function ok(summary: string, structured: Record<string, unknown>): CallToolResult {
  return {
    content: [
      { type: 'text', text: summary },
      { type: 'text', text: JSON.stringify(structured, null, 2) },
    ],
    structuredContent: structured,
  };
}

/** Tool-level error. Messages never contain absolute paths or stack traces. */
export function toolError(code: string, message: string): CallToolResult {
  return {
    isError: true,
    content: [{ type: 'text', text: `${code}: ${message}` }],
  };
}

/** Maps any thrown value to a safe tool error. */
export function errorResult(error: unknown, logger: Logger, tool: string): CallToolResult {
  if (error instanceof WorkspaceError) {
    logger.debug(`${tool} refused: ${error.code}`);
    return toolError(error.code, error.message);
  }
  logger.error(`${tool} failed: ${error instanceof Error ? error.name : 'unknown error'}`);
  return toolError('internal_error', 'The request could not be completed.');
}
