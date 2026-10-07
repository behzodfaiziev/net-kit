import assert from 'node:assert/strict';
import { join } from 'node:path';
import { describe, it } from 'node:test';

import { Client, InMemoryTransport } from '@modelcontextprotocol/client';

import { createNetKitMcpServer } from '../src/server/createServer.js';
import { authorizeRoots } from '../src/workspace/roots.js';
import * as F from './fixtures/dart.js';
import { tempTree } from './helpers.js';

describe('concurrency', () => {
  it('keeps every concurrent request on the root it selected', async () => {
    const tree = tempTree({
      'example_app/pubspec.yaml': F.PUBSPEC_V6,
      'example_app/lib/upload.dart': F.SIGNED_UPLOAD_BAD,
      'legacy_app/pubspec.yaml': F.PUBSPEC_V5,
      'legacy_app/lib/main.dart': F.LEGACY_V5,
    });
    const roots = authorizeRoots([
      { path: join(tree.dir, 'example_app') },
      { path: join(tree.dir, 'legacy_app') },
    ]);
    const server = createNetKitMcpServer({ workspace: { policy: { mode: 'startup', roots } } });
    const [clientSide, serverSide] = InMemoryTransport.createLinkedPair();
    const client = new Client({ name: 'concurrency-test', version: '0.0.0' });
    await Promise.all([server.connect(serverSide), client.connect(clientSide)]);
    try {
      const calls = Array.from({ length: 24 }, (_, i) => {
        const root = i % 2 === 0 ? 'root1' : 'root2';
        return client
          .callTool({ name: 'inspect_netkit_usage', arguments: { root } })
          .then((result) => ({
            root,
            result: result.structuredContent as {
              project: { root: { id: string }; targetMajor: number };
              findings: { ruleId: string }[];
            },
          }));
      });
      const knowledge = Array.from({ length: 8 }, () =>
        client.callTool({ name: 'search_netkit', arguments: { query: 'cancellation token' } }),
      );
      const results = await Promise.all(calls);
      await Promise.all(knowledge);
      for (const { root, result } of results) {
        assert.equal(result.project.root.id, root);
        if (root === 'root1') {
          assert.equal(result.project.targetMajor, 6);
          assert.ok(result.findings.some((f) => f.ruleId === 'NK001'));
        } else {
          assert.equal(result.project.targetMajor, 5);
          assert.ok(result.findings.some((f) => f.ruleId === 'NK005'));
          assert.ok(!result.findings.some((f) => f.ruleId === 'NK001'));
        }
      }
    } finally {
      await client.close();
      await server.close();
      tree.cleanup();
    }
  });
});
