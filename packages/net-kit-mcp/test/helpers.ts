import { mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';

/** Creates a temporary directory tree; returns its canonical path and a cleanup. */
export function tempTree(files: Record<string, string | Buffer>): {
  dir: string;
  cleanup: () => void;
} {
  const dir = realpathSync.native(mkdtempSync(join(tmpdir(), 'netkit-mcp-test-')));
  for (const [relative, content] of Object.entries(files)) {
    const target = join(dir, relative);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, content);
  }
  return {
    dir,
    cleanup: () => {
      rmSync(dir, { recursive: true, force: true });
    },
  };
}
