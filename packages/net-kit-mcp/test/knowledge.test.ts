import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, it } from 'node:test';

import { generateKnowledge, serializeKnowledge } from '../src/knowledge/generate.js';
import { apiUri, docUri, KnowledgeBase } from '../src/knowledge/knowledgeBase.js';
import { API, DOC } from '../src/knowledge/refs.js';
import { PATTERNS } from '../src/patterns/catalog.js';
import { packageRoot } from '../src/util/packageRoot.js';

const kb = KnowledgeBase.load();
const netKitRoot = join(packageRoot(), '..', 'net-kit');
const inMonorepo = existsSync(join(netKitRoot, 'pubspec.yaml'));

function resolves(uri: string): boolean {
  if (uri.startsWith('netkit://api/')) {
    return kb.symbol(decodeURIComponent(uri.slice('netkit://api/'.length))) !== undefined;
  }
  if (uri.startsWith('netkit://docs/')) {
    const id = decodeURIComponent(uri.slice('netkit://docs/'.length));
    return (
      kb.doc(id) !== undefined ||
      kb.section(id) !== undefined ||
      id === 'streaming' ||
      id === 'index'
    );
  }
  return false;
}

describe('knowledge artifact', () => {
  it('records the net_kit version from package metadata', () => {
    assert.match(kb.version, /^\d+\.\d+\.\d+/);
    if (inMonorepo) {
      const pubspec = readFileSync(join(netKitRoot, 'pubspec.yaml'), 'utf8');
      assert.equal(kb.version, /^version:\s*(\S+)/m.exec(pubspec)?.[1]);
    }
  });

  it(
    'is up to date with the net_kit source (source is authoritative for the API)',
    { skip: !inMonorepo },
    () => {
      const committed = readFileSync(
        join(packageRoot(), 'generated', 'netkit-knowledge.json'),
        'utf8',
      );
      assert.equal(
        serializeKnowledge(generateKnowledge(netKitRoot)),
        committed,
        'run `npm run generate`',
      );
    },
  );

  it('contains no absolute paths, HTML comments, or private symbols', () => {
    const text = readFileSync(join(packageRoot(), 'generated', 'netkit-knowledge.json'), 'utf8');
    assert.ok(!/\/Users\/|\/home\/|[A-Z]:\\\\/.test(text));
    assert.ok(!text.includes('<!--'));
    for (const symbol of kb.symbols) {
      assert.ok(!symbol.name.startsWith('_'), symbol.name);
      assert.ok(
        symbol.members.every((m) => !m.name.startsWith('_')),
        symbol.name,
      );
      assert.ok(!symbol.source.file.startsWith('/'), symbol.source.file);
    }
  });

  it('indexes the public API', () => {
    for (const name of [
      'NetKitManager',
      'AuthPolicy',
      'NetKitTransport',
      'RawHttpClient',
      'RawHttpRequest',
      'ReplayableRawHttpBody',
      'FileRawHttpBody',
      'NetKitCancellationToken',
      'OnSessionInvalidated',
    ]) {
      assert.ok(kb.symbol(name), name);
    }
    assert.deepEqual(
      kb.symbol('AuthPolicy')?.members.map((m) => m.name),
      ['inherit', 'none', 'required'],
    );
    assert.ok(
      kb
        .symbol('NetKitManager')
        ?.members.some((m) => m.name === 'uploadFile' && m.kind === 'method'),
    );
    assert.ok(kb.symbol('ApiFailureType')?.members.some((m) => m.name === 'sessionInvalidated'));
  });

  it('keeps Dio-backed symbols on the adapter entrypoint only', () => {
    const dio = kb.symbol('DioNetKitTransport');
    assert.deepEqual(dio?.entrypoints, ['package:net_kit/net_kit_dio.dart']);
    const main = kb.artifact.entrypoints.find((e) => e.uri === 'package:net_kit/net_kit.dart');
    assert.deepEqual(main?.reexports, []);
  });

  it('handles unknown symbols with suggestions', () => {
    assert.equal(kb.symbol('NoSuchThing'), undefined);
    assert.ok(kb.similarSymbols('AuthPolcy').includes('AuthPolicy'));
    assert.equal(kb.symbol('authpolicy')?.name, 'AuthPolicy');
  });

  it('searches API and documentation', () => {
    assert.equal(kb.search('FileRawHttpBody', 3)[0]?.title, 'FileRawHttpBody');
    const session = kb.search('session invalidated refresh 401 offline', 5, ['docs', 'security']);
    assert.ok(
      session.some((m) => m.resource.includes('session')),
      JSON.stringify(session.map((m) => m.resource)),
    );
    const migration = kb.search('containsAccessToken skipTokenRefresh', 5, ['migration']);
    assert.ok(migration.length > 0 && migration.every((m) => m.area === 'migration'));
    assert.deepEqual(kb.search('', 5), []);
  });

  it('keeps resource URIs stable', () => {
    assert.equal(apiUri('AuthPolicy'), 'netkit://api/AuthPolicy');
    assert.equal(
      docUri('auth.when-the-session-ends-and-when-it-does-not'),
      'netkit://docs/auth.when-the-session-ends-and-when-it-does-not',
    );
  });

  it('every cited resource and pattern symbol exists', () => {
    for (const uri of [...Object.values(DOC), ...Object.values(API)]) {
      assert.ok(resolves(uri), uri);
    }
    for (const pattern of PATTERNS) {
      for (const symbol of pattern.symbols)
        assert.ok(kb.symbol(symbol), `${pattern.id}: ${symbol}`);
      for (const uri of pattern.resources) assert.ok(resolves(uri), `${pattern.id}: ${uri}`);
    }
  });
});
