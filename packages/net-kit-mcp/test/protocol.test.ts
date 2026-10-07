import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { after, before, describe, it } from 'node:test';

import { Client } from '@modelcontextprotocol/client';
import { StdioClientTransport } from '@modelcontextprotocol/client/stdio';

import { KnowledgeBase } from '../src/knowledge/knowledgeBase.js';
import { packageRoot } from '../src/util/packageRoot.js';
import * as F from './fixtures/dart.js';
import { tempTree } from './helpers.js';

/** End-to-end MCP tests against the built stdio server in a child process. */

const SERVER = join(packageRoot(), 'dist', 'src', 'bin', 'stdio.js');
const VERSION = KnowledgeBase.load().version;
const FORBIDDEN_TOOL = /write|edit|patch|delete|rename|run|exec|shell|command/i;

function snapshot(dir: string): string {
  const hash = createHash('sha256');
  const walk = (current: string): void => {
    for (const entry of readdirSync(current, { withFileTypes: true }).sort((a, b) =>
      a.name.localeCompare(b.name),
    )) {
      const path = join(current, entry.name);
      if (entry.isDirectory()) {
        hash.update(`d:${path}`);
        walk(path);
      } else {
        hash.update(`f:${path}:${statSync(path).mtimeMs}:`).update(readFileSync(path));
      }
    }
  };
  walk(dir);
  return hash.digest('hex');
}

async function connect(options: {
  args?: string[];
  roots?: { uri: string; name: string }[];
  modern?: boolean;
}): Promise<Client> {
  const client = new Client(
    { name: 'protocol-test', version: '0.0.0' },
    {
      ...(options.roots === undefined ? {} : { capabilities: { roots: {} } }),
      ...(options.modern === true ? { versionNegotiation: { mode: 'auto' as const } } : {}),
    },
  );
  if (options.roots !== undefined) {
    const roots = options.roots;
    client.setRequestHandler('roots/list', () => ({ roots }));
  }
  await client.connect(
    new StdioClientTransport({
      command: process.execPath,
      args: [SERVER, ...(options.args ?? [])],
      stderr: 'ignore',
    }),
  );
  return client;
}

function structured(result: unknown): Record<string, unknown> {
  return (result as { structuredContent: Record<string, unknown> }).structuredContent;
}

function firstText(result: unknown): string {
  return (result as { content: { text: string }[] }).content[0]?.text ?? '';
}

describe('MCP protocol over stdio', () => {
  let tree: { dir: string; cleanup: () => void };
  let before_: string;

  before(() => {
    tree = tempTree({
      'example_app/pubspec.yaml': F.PUBSPEC_V6,
      'example_app/lib/upload.dart': F.SIGNED_UPLOAD_BAD,
      'example_app/lib/auth.dart': F.GOOD_AUTH,
      'example_app/.env': 'API_KEY=not-a-real-key\n',
      'other_app/lib/main.dart': F.LEGACY_V5,
    });
    before_ = snapshot(tree.dir);
  });

  after(() => {
    assert.equal(snapshot(tree.dir), before_, 'the server must not modify project files');
    tree.cleanup();
  });

  for (const modern of [false, true]) {
    it(`serves tools, resources, and prompts (${modern ? '2026-07-28 era' : '2025 era'})`, async () => {
      const app = join(tree.dir, 'example_app');
      const client = await connect({
        roots: [{ uri: pathToFileURL(app).href, name: 'example_app' }],
        modern,
      });
      try {
        assert.equal(client.getProtocolEra(), modern ? 'modern' : 'legacy');

        const tools = (await client.listTools()).tools;
        assert.deepEqual(tools.map((t) => t.name).sort(), [
          'check_v5_to_v6_migration',
          'explain_netkit_pattern',
          'get_netkit_api',
          'inspect_netkit_usage',
          'list_workspace_roots',
          'recommend_netkit_pattern',
          'review_auth_flow',
          'review_refresh_flow',
          'review_streaming_usage',
          'review_upload_flow',
          'search_netkit',
          'validate_netkit_configuration',
        ]);
        for (const tool of tools) {
          assert.ok(!FORBIDDEN_TOOL.test(tool.name), tool.name);
          assert.equal(tool.annotations!.readOnlyHint, true, tool.name);
          assert.equal(tool.annotations!.destructiveHint, false, tool.name);
          assert.ok(tool.outputSchema !== undefined, tool.name);
        }

        const search = await client.callTool({
          name: 'search_netkit',
          arguments: { query: 'AuthPolicy', limit: 3 },
        });
        assert.equal(structured(search).netKitVersion, VERSION);

        const api = await client.callTool({
          name: 'get_netkit_api',
          arguments: { symbol: 'AuthPolicy' },
        });
        assert.deepEqual(
          (structured(api).members as { name: string }[]).map((m) => m.name),
          ['inherit', 'none', 'required'],
        );
        const missing = await client.callTool({
          name: 'get_netkit_api',
          arguments: { symbol: 'AuthPolcy' },
        });
        assert.equal(missing.isError, true);
        assert.match(firstText(missing), /symbol_not_found.*AuthPolicy/);

        const rec = await client.callTool({
          name: 'recommend_netkit_pattern',
          arguments: { authenticated: true, externalUrl: true, largeRequestBody: true },
        });
        assert.equal(structured(rec).client, 'RawHttpClient (NetKitTransport)');

        const roots = await client.callTool({ name: 'list_workspace_roots', arguments: {} });
        assert.deepEqual(structured(roots).roots, [{ id: 'root1', name: 'example_app' }]);
        assert.ok(!JSON.stringify(roots).includes(tree.dir), 'no absolute paths');

        const inspect = await client.callTool({ name: 'inspect_netkit_usage', arguments: {} });
        assert.equal(inspect.isError, undefined);
        const findings = structured(inspect).findings as { ruleId: string; file: string }[];
        assert.ok(findings.some((f) => f.ruleId === 'NK001' && f.file === 'lib/upload.dart'));
        assert.ok(!JSON.stringify(inspect).includes(tree.dir), 'no absolute paths in results');

        const escape = await client.callTool({
          name: 'review_upload_flow',
          arguments: { paths: ['../other_app/lib'] },
        });
        assert.equal(escape.isError, true);
        assert.match(firstText(escape), /^path_escape:/);
        const secret = await client.callTool({
          name: 'inspect_netkit_usage',
          arguments: { paths: ['.env'] },
        });
        assert.match(firstText(secret), /^sensitive_file:/);

        const resources = (await client.listResources()).resources.map((r) => r.uri);
        for (const uri of [
          'netkit://overview',
          'netkit://version',
          'netkit://api/index',
          'netkit://docs/index',
          'netkit://api/AuthPolicy',
          'netkit://docs/streaming',
        ]) {
          assert.ok(resources.includes(uri), uri);
        }
        const templates = (await client.listResourceTemplates()).resourceTemplates
          .map((t) => t.uriTemplate)
          .sort();
        assert.deepEqual(templates, ['netkit://api/{symbol}', 'netkit://docs/{section}']);
        const version = await client.readResource({ uri: 'netkit://version' });
        assert.equal(
          (JSON.parse((version.contents[0] as { text: string }).text) as { version: string })
            .version,
          VERSION,
        );
        const symbol = await client.readResource({ uri: 'netkit://api/FileRawHttpBody' });
        assert.match((symbol.contents[0] as { text: string }).text, /final class FileRawHttpBody/);
        const section = await client.readResource({
          uri: 'netkit://docs/auth.when-the-session-ends-and-when-it-does-not',
        });
        assert.match((section.contents[0] as { text: string }).text, /refresh endpoint/i);
        await assert.rejects(
          client.readResource({ uri: 'netkit://api/NoSuchSymbol' }),
          /NoSuchSymbol|not found/i,
        );
        await assert.rejects(
          client.readResource({ uri: 'netkit://docs/no-such-doc' }),
          /no-such-doc|not found/i,
        );

        const prompts = (await client.listPrompts()).prompts.map((p) => p.name).sort();
        assert.deepEqual(prompts, [
          'design-netkit-streaming',
          'design-netkit-upload',
          'migrate-netkit-v5-to-v6',
          'review-netkit-auth',
          'review-netkit-network-layer',
        ]);
        const prompt = await client.getPrompt({
          name: 'design-netkit-upload',
          arguments: { destination: 'signed external URL' },
        });
        const promptText = (prompt.messages[0]?.content as { text: string }).text;
        assert.match(promptText, /recommend_netkit_pattern/);
        assert.match(promptText, /Do not edit files/);
      } finally {
        await client.close();
      }
    });
  }

  it('declines project inspection when no root is authorized', async () => {
    const client = await connect({});
    try {
      const result = await client.callTool({ name: 'inspect_netkit_usage', arguments: {} });
      assert.equal(result.isError, true);
      assert.match(firstText(result), /^no_authorized_root:/);
      const knowledge = await client.callTool({
        name: 'search_netkit',
        arguments: { query: 'upload' },
      });
      assert.equal(knowledge.isError, undefined);
    } finally {
      await client.close();
    }
  });

  it('uses startup roots as independent boundaries', async () => {
    const client = await connect({
      args: ['--root', join(tree.dir, 'example_app'), '--root', join(tree.dir, 'other_app')],
    });
    try {
      const roots = await client.callTool({ name: 'list_workspace_roots', arguments: {} });
      assert.deepEqual(structured(roots).roots, [
        { id: 'root1', name: 'example_app' },
        { id: 'root2', name: 'other_app' },
      ]);
      const ambiguous = await client.callTool({ name: 'check_v5_to_v6_migration', arguments: {} });
      assert.match(firstText(ambiguous), /^ambiguous_root:/);
      const migration = await client.callTool({
        name: 'check_v5_to_v6_migration',
        arguments: { root: 'root2' },
      });
      const checklist = (structured(migration).details as { checklist: { item: string }[] })
        .checklist;
      assert.ok(checklist.some((c) => c.item === 'auth-flags'));
      const cross = await client.callTool({
        name: 'inspect_netkit_usage',
        arguments: { root: 'root1', paths: ['../other_app/lib/main.dart'] },
      });
      assert.match(firstText(cross), /^path_escape:/);
    } finally {
      await client.close();
    }
  });

  it('knowledge-only mode exposes no workspace tools', async () => {
    const client = await connect({ args: ['--no-workspace'] });
    try {
      const tools = (await client.listTools()).tools.map((t) => t.name).sort();
      assert.deepEqual(tools, [
        'explain_netkit_pattern',
        'get_netkit_api',
        'recommend_netkit_pattern',
        'search_netkit',
      ]);
      const prompts = (await client.listPrompts()).prompts.map((p) => p.name).sort();
      assert.deepEqual(prompts, ['design-netkit-streaming', 'design-netkit-upload']);
    } finally {
      await client.close();
    }
  });

  it('writes only JSON-RPC to stdout and exits cleanly when stdin closes', async () => {
    const child = spawn(process.execPath, [SERVER, '--log-level', 'debug'], {
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk: Buffer) => (stdout += chunk.toString('utf8')));
    child.stderr.on('data', (chunk: Buffer) => (stderr += chunk.toString('utf8')));
    const send = (message: unknown): void => {
      child.stdin.write(`${JSON.stringify(message)}\n`);
    };
    send({
      jsonrpc: '2.0',
      id: 1,
      method: 'initialize',
      params: {
        protocolVersion: '2025-06-18',
        capabilities: {},
        clientInfo: { name: 'raw', version: '0' },
      },
    });
    await new Promise((resolve) => setTimeout(resolve, 300));
    send({ jsonrpc: '2.0', method: 'notifications/initialized' });
    send({ jsonrpc: '2.0', id: 2, method: 'tools/list' });
    send({
      jsonrpc: '2.0',
      id: 3,
      method: 'tools/call',
      params: { name: 'search_netkit', arguments: { query: 'cancellation' } },
    });
    send({ jsonrpc: '2.0', id: 4, method: 'resources/read', params: { uri: 'netkit://overview' } });
    await new Promise((resolve) => setTimeout(resolve, 600));
    child.stdin.end();
    const code = await new Promise<number | null>((resolve) => child.on('exit', resolve));

    assert.equal(code, 0);
    const lines = stdout.split('\n').filter((line) => line.trim() !== '');
    assert.ok(lines.length >= 4, stdout);
    for (const line of lines) {
      const message = JSON.parse(line) as { jsonrpc?: string };
      assert.equal(message.jsonrpc, '2.0');
    }
    const ids = lines
      .map((line) => (JSON.parse(line) as { id?: number }).id)
      .filter((id) => id !== undefined);
    assert.deepEqual(ids.sort(), [1, 2, 3, 4]);
    assert.match(stderr, /\[net-kit-mcp\]/, 'diagnostics go to stderr');
    assert.ok(!stderr.includes('cancellation'), 'tool arguments are not logged');
  });
});
