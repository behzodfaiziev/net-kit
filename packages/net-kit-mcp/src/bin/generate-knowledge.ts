#!/usr/bin/env node
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { argv, exit, stderr } from 'node:process';

import { generateKnowledge, serializeKnowledge } from '../knowledge/generate.js';
import { packageRoot } from '../util/packageRoot.js';

/**
 * Regenerates `generated/netkit-knowledge.json` from the adjacent net_kit
 * package (`../net-kit` relative to this package), or from `--netkit <dir>`.
 * With `--check`, exits non-zero when the committed artifact is stale.
 */
function main(): number {
  const args = argv.slice(2);
  const check = args.includes('--check');
  const flag = args.indexOf('--netkit');
  const root = packageRoot();
  const netKitRoot =
    flag >= 0 && args[flag + 1] !== undefined
      ? resolve(args[flag + 1] ?? '')
      : join(root, '..', 'net-kit');
  if (!existsSync(join(netKitRoot, 'pubspec.yaml'))) {
    stderr.write('net_kit package not found next to this package; pass --netkit <dir>.\n');
    return 2;
  }
  const text = serializeKnowledge(generateKnowledge(netKitRoot));
  const target = join(root, 'generated', 'netkit-knowledge.json');
  if (check) {
    const current = existsSync(target) ? readFileSync(target, 'utf8') : '';
    if (current !== text) {
      stderr.write('generated/netkit-knowledge.json is out of date. Run `npm run generate`.\n');
      return 1;
    }
    stderr.write('generated/netkit-knowledge.json is up to date.\n');
    return 0;
  }
  writeFileSync(target, text);
  stderr.write('Wrote generated/netkit-knowledge.json\n');
  return 0;
}

exit(main());
