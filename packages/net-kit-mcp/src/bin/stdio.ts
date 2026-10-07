#!/usr/bin/env node
import { serveStdio } from '@modelcontextprotocol/server/stdio';
import { argv, exit, stderr } from 'node:process';

import { KnowledgeBase } from '../knowledge/knowledgeBase.js';
import { createNetKitMcpServer } from '../server/createServer.js';
import type { RootPolicy } from '../server/roots.js';
import { createLogger, type LogLevel } from '../util/log.js';
import { packageVersion } from '../util/packageRoot.js';
import { WorkspaceError } from '../workspace/errors.js';
import { DEFAULT_LIMITS, type WorkspaceLimits } from '../workspace/limits.js';
import { authorizeRoots } from '../workspace/roots.js';

/**
 * stdio entrypoint. stdout carries only MCP messages; diagnostics go to
 * stderr. Nothing is scanned at startup: knowledge loads on first use and
 * project files are read only by workspace tools, inside authorized roots.
 */

const USAGE = `net-kit-mcp ${packageVersion()}

Usage: net-kit-mcp [options]

  --root <dir>            Authorize a project directory for read-only analysis
                          (repeatable). When given, client roots are ignored.
  --no-workspace          Disable workspace tools (knowledge only).
  --log-level <level>     silent | error | info | debug (default: error)
  --max-file-bytes <n>    Largest file read (default ${DEFAULT_LIMITS.maxFileBytes})
  --max-files <n>         Files read per request (default ${DEFAULT_LIMITS.maxFiles})
  --max-total-bytes <n>   Bytes read per request (default ${DEFAULT_LIMITS.maxTotalBytes})
  --max-diagnostics <n>   Findings returned per request (default ${DEFAULT_LIMITS.maxDiagnostics})
  --help, --version
`;

interface Cli {
  roots: string[];
  workspace: boolean;
  logLevel: LogLevel;
  limits: WorkspaceLimits;
}

function parse(args: readonly string[]): Cli | number {
  const cli: Cli = { roots: [], workspace: true, logLevel: 'error', limits: { ...DEFAULT_LIMITS } };
  const positive = (flag: string, value: string | undefined): number => {
    const n = Number(value);
    if (!Number.isInteger(n) || n <= 0) throw new Error(`${flag} needs a positive integer`);
    return n;
  };
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    const value = args[i + 1];
    switch (flag) {
      case '--help':
        stderr.write(USAGE);
        return 0;
      case '--version':
        stderr.write(`${packageVersion()}\n`);
        return 0;
      case '--root':
        if (value === undefined) throw new Error('--root needs a directory');
        cli.roots.push(value);
        i++;
        break;
      case '--no-workspace':
        cli.workspace = false;
        break;
      case '--log-level':
        if (value !== 'silent' && value !== 'error' && value !== 'info' && value !== 'debug') {
          throw new Error('--log-level must be silent, error, info, or debug');
        }
        cli.logLevel = value;
        i++;
        break;
      case '--max-file-bytes':
        cli.limits = { ...cli.limits, maxFileBytes: positive(flag, value) };
        i++;
        break;
      case '--max-files':
        cli.limits = { ...cli.limits, maxFiles: positive(flag, value) };
        i++;
        break;
      case '--max-total-bytes':
        cli.limits = { ...cli.limits, maxTotalBytes: positive(flag, value) };
        i++;
        break;
      case '--max-diagnostics':
        cli.limits = { ...cli.limits, maxDiagnostics: positive(flag, value) };
        i++;
        break;
      default:
        throw new Error(`Unknown option ${String(flag)}`);
    }
  }
  return cli;
}

function main(): number {
  let cli: Cli | number;
  try {
    cli = parse(argv.slice(2));
  } catch (error) {
    stderr.write(`${error instanceof Error ? error.message : 'Invalid arguments'}\n\n${USAGE}`);
    return 2;
  }
  if (typeof cli === 'number') return cli;
  const logger = createLogger(cli.logLevel);

  let policy: RootPolicy = { mode: 'client' };
  if (cli.roots.length > 0) {
    try {
      policy = { mode: 'startup', roots: authorizeRoots(cli.roots.map((path) => ({ path }))) };
    } catch (error) {
      stderr.write(`${error instanceof WorkspaceError ? error.message : 'Invalid --root'}\n`);
      return 2;
    }
  }

  // Loaded on first use and shared by the per-connection server instance.
  let knowledge: KnowledgeBase | undefined;
  const handle = serveStdio(
    () =>
      createNetKitMcpServer({
        logger,
        knowledge: () => (knowledge ??= KnowledgeBase.load()),
        ...(cli.workspace ? { workspace: { policy, limits: cli.limits } } : {}),
      }),
    {
      onerror: (error) => {
        logger.error(`transport: ${error.name}`);
      },
    },
  );

  let closing = false;
  const shutdown = async (): Promise<void> => {
    if (closing) return;
    closing = true;
    logger.info('shutting down');
    try {
      await handle.close();
    } finally {
      exit(0);
    }
  };
  process.on('SIGINT', () => void shutdown());
  process.on('SIGTERM', () => void shutdown());
  process.stdin.on('end', () => void shutdown());

  logger.info(`ready (workspace: ${cli.workspace ? policy.mode : 'disabled'})`);
  return -1;
}

try {
  const code = main();
  if (code >= 0) exit(code);
} catch (error) {
  stderr.write(`net-kit-mcp failed to start: ${error instanceof Error ? error.name : 'error'}\n`);
  exit(1);
}
