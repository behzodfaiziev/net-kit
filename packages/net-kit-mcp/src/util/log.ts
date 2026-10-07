import { stderr } from 'node:process';

/**
 * Diagnostic logging to stderr only (stdout carries MCP messages).
 *
 * Callers log event names, tool names, durations, and error codes, never
 * file contents, tool arguments, tokens, or absolute workspace paths.
 */
export type LogLevel = 'silent' | 'error' | 'info' | 'debug';

const ORDER: Record<LogLevel, number> = { silent: 0, error: 1, info: 2, debug: 3 };

export interface Logger {
  error(message: string): void;
  info(message: string): void;
  debug(message: string): void;
}

export function createLogger(
  level: LogLevel,
  write: (line: string) => void = (line) => {
    stderr.write(line);
  },
): Logger {
  const emit = (at: LogLevel, message: string): void => {
    if (ORDER[at] <= ORDER[level]) {
      write(`[net-kit-mcp] ${at}: ${message}\n`);
    }
  };
  return {
    error: (message) => {
      emit('error', message);
    },
    info: (message) => {
      emit('info', message);
    },
    debug: (message) => {
      emit('debug', message);
    },
  };
}

export const silentLogger: Logger = {
  error: () => undefined,
  info: () => undefined,
  debug: () => undefined,
};
