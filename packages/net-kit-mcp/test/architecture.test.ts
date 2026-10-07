import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { describe, it } from 'node:test';

import { packageRoot } from '../src/util/packageRoot.js';

/**
 * Source-level guards for the read-only, no-execution design. The build-time
 * knowledge generator is the only module allowed to write, and nothing the
 * server loads may import it.
 */

const SRC = join(packageRoot(), 'src');
const GENERATOR_MODULES = new Set(['bin/generate-knowledge.ts', 'knowledge/generate.ts']);
const FORBIDDEN =
  /\b(writeFile|writeFileSync|appendFile|createWriteStream|mkdirSync|mkdir|rmSync|rm|unlink|unlinkSync|rename|renameSync|copyFile|chmod|truncate)\s*\(|\bchild_process\b|\bnode:net\b|\bnode:http\b|\bnode:https\b|\bfetch\s*\(|\beval\s*\(|new Function\s*\(/;

function sources(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) =>
    entry.isDirectory()
      ? sources(join(dir, entry.name))
      : entry.name.endsWith('.ts')
        ? [join(dir, entry.name)]
        : [],
  );
}

describe('architecture', () => {
  const files = sources(SRC).map((file) => ({
    rel: relative(SRC, file).split('\\').join('/'),
    text: readFileSync(file, 'utf8'),
  }));

  it('server modules never write files, spawn processes, open connections, or eval', () => {
    for (const { rel, text } of files) {
      if (GENERATOR_MODULES.has(rel)) continue;
      const code = text
        .split('\n')
        .filter((line) => !/^\s*(\/\/|\*|\/\*\*)/.test(line))
        .join('\n');
      assert.ok(!FORBIDDEN.test(code), `${rel} uses a forbidden API`);
    }
  });

  it('only the generator entrypoint imports the generator', () => {
    for (const { rel, text } of files) {
      if (rel === 'bin/generate-knowledge.ts') continue;
      assert.ok(
        !/from '\.\.?\/.*generate\.js'/.test(text),
        `${rel} imports the knowledge generator`,
      );
    }
  });

  it('no tool is registered with a mutating or executing name', () => {
    const names = files.flatMap(({ text }) =>
      [...text.matchAll(/registerTool\(\s*'([^']+)'/g)].map((m) => m[1] ?? ''),
    );
    const specs = files.flatMap(({ text }) =>
      [...text.matchAll(/\bname: '([a-z_]+)',\n\s+title:/g)].map((m) => m[1] ?? ''),
    );
    const all = [...names, ...specs];
    assert.ok(all.length >= 12, all.join(','));
    for (const name of all) {
      assert.ok(!/write|edit|patch|delete|rename|run|exec|shell|command|apply/i.test(name), name);
    }
  });

  it('the runtime never loads the build-time generator, which is excluded from the package', () => {
    const reachable = new Set<string>();
    const visit = (file: string): void => {
      if (reachable.has(file)) return;
      reachable.add(file);
      for (const match of readFileSync(file, 'utf8').matchAll(/from '(\.[^']+)'/g)) {
        visit(resolve(dirname(file), (match[1] ?? '').replace(/\.js$/, '.ts')));
      }
    };
    visit(join(SRC, 'bin', 'stdio.ts'));
    visit(join(SRC, 'index.ts'));
    const unreachable = files
      .map(({ rel }) => rel)
      .filter((rel) => !reachable.has(join(SRC, rel)))
      .sort();
    const manifest = JSON.parse(readFileSync(join(packageRoot(), 'package.json'), 'utf8')) as {
      files: string[];
    };
    const excluded = manifest.files
      .filter((entry) => entry.startsWith('!dist/src/'))
      .map((entry) => entry.slice('!dist/src/'.length).replace(/\.js$/, '.ts'))
      .sort();
    assert.deepEqual(unreachable, excluded);
    assert.deepEqual(unreachable, [
      'bin/generate-knowledge.ts',
      'knowledge/dartApi.ts',
      'knowledge/generate.ts',
      'knowledge/markdown.ts',
    ]);
  });
});
