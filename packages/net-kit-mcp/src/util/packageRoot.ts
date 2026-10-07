import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const PACKAGE_NAME = 'flutter-net-kit-mcp';

/** Directory of this package (the one containing its package.json). */
export function packageRoot(): string {
  let dir = dirname(fileURLToPath(import.meta.url));
  for (;;) {
    const manifest = join(dir, 'package.json');
    if (existsSync(manifest)) {
      const parsed = JSON.parse(readFileSync(manifest, 'utf8')) as { name?: unknown };
      if (parsed.name === PACKAGE_NAME) {
        return dir;
      }
    }
    const parent = dirname(dir);
    if (parent === dir) {
      throw new Error(`Could not locate the ${PACKAGE_NAME} package root`);
    }
    dir = parent;
  }
}

/** This package's version from package.json. */
export function packageVersion(): string {
  const manifest = JSON.parse(readFileSync(join(packageRoot(), 'package.json'), 'utf8')) as {
    version?: unknown;
  };
  return typeof manifest.version === 'string' ? manifest.version : '0.0.0';
}
