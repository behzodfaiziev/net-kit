/** Reads the net_kit dependency from pubspec.yaml / pubspec.lock text. */

export function netKitConstraint(pubspec: string): string | null {
  const lines = pubspec.split('\n');
  let section: string | null = null;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i] ?? '';
    const top = /^([a-z_]+):\s*$/.exec(line);
    if (top !== null) {
      section = top[1] ?? null;
      continue;
    }
    if (section !== 'dependencies' && section !== 'dependency_overrides') continue;
    const dep = /^ {2}net_kit:\s*(.*)$/.exec(line);
    if (dep === null) continue;
    const inline = (dep[1] ?? '').trim().replace(/^['"]|['"]$/g, '');
    if (inline !== '') return inline;
    // Nested form: `version:` / `path:` / `git:` on the following lines.
    for (let j = i + 1; j < lines.length && /^ {4}/.test(lines[j] ?? ''); j++) {
      const nested = /^ {4}(version|path|git):\s*(.*)$/.exec(lines[j] ?? '');
      if (nested !== null) {
        return nested[1] === 'version'
          ? (nested[2] ?? '').trim().replace(/^['"]|['"]$/g, '')
          : `${nested[1]} dependency`;
      }
    }
    return 'any';
  }
  return null;
}

export function lockedNetKitVersion(lock: string): string | null {
  const match = /^ {2}net_kit:\s*\n(?: {4}.*\n)*? {4}version:\s*"?([^"\n]+)"?/m.exec(lock);
  return match?.[1]?.trim() ?? null;
}

/** Major version a constraint or version targets, when determinable. */
export function majorOf(value: string | null): number | null {
  if (value === null) return null;
  const match = /(\d+)\.\d+/.exec(value);
  return match?.[1] === undefined ? null : Number(match[1]);
}
