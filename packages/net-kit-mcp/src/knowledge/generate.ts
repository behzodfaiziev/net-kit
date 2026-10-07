import { readFileSync } from 'node:fs';
import { dirname, join, posix, relative, sep } from 'node:path';

import { parseLibrary, type Declaration } from './dartApi.js';
import { splitSections } from './markdown.js';
import type {
  ApiSymbol,
  DocCategory,
  DocEntry,
  EntrypointInfo,
  KnowledgeArtifact,
} from './types.js';

/**
 * Builds the knowledge artifact from a net_kit checkout.
 *
 * Reads only the net_kit package: `lib/`, its public Markdown docs, and
 * `pubspec.yaml`. The output is deterministic and contains only paths
 * relative to the repository.
 */

interface DocSpec {
  readonly id: string;
  readonly title: string;
  readonly category: DocCategory;
  /** Path relative to the net_kit package root. */
  readonly file: string;
}

export const DOC_SPECS: readonly DocSpec[] = [
  { id: 'readme', title: 'net_kit README', category: 'docs', file: 'README.md' },
  { id: 'auth', title: 'Token management', category: 'auth', file: 'TOKEN_MANAGEMENT.md' },
  { id: 'migration', title: 'Migration guide', category: 'migration', file: 'MIGRATION.md' },
  { id: 'examples', title: 'Examples', category: 'examples', file: 'EXAMPLES.md' },
  { id: 'changelog', title: 'Changelog', category: 'changelog', file: 'CHANGELOG.md' },
];

const ENTRYPOINTS: readonly { file: string; description: string }[] = [
  {
    file: 'lib/net_kit.dart',
    description: 'Main public API. Exposes only net_kit-owned types.',
  },
  {
    file: 'lib/net_kit_dio.dart',
    description: 'Dio adapter entrypoint: DioNetKitTransport and a re-export of package:dio.',
  },
];

function toPosix(path: string): string {
  return path.split(sep).join(posix.sep);
}

/** Minimal pubspec reader for the fields the artifact needs. */
function readPubspec(text: string): KnowledgeArtifact['netKit'] {
  const field = (name: string): string =>
    new RegExp(`^${name}:\\s*['"]?([^'"\\n]+)['"]?\\s*$`, 'm').exec(text)?.[1]?.trim() ?? '';
  const sdk = /^environment:\s*\n\s+sdk:\s*['"]?([^'"\n]+)['"]?/m.exec(text)?.[1]?.trim() ?? '';
  const dependencies: Record<string, string> = {};
  const block = /^dependencies:\s*\n((?:[ \t]+.*\n?)*)/m.exec(text)?.[1] ?? '';
  for (const line of block.split('\n')) {
    const dep = /^\s{2}([a-z0-9_]+):\s*(.+)$/.exec(line);
    if (dep?.[1] !== undefined && dep[2] !== undefined) {
      dependencies[dep[1]] = dep[2].trim();
    }
  }
  return { package: field('name'), version: field('version'), sdkConstraint: sdk, dependencies };
}

export function generateKnowledge(netKitRoot: string): KnowledgeArtifact {
  const read = (relativePath: string): string =>
    readFileSync(join(netKitRoot, relativePath), 'utf8');
  const netKit = readPubspec(read('pubspec.yaml'));

  // Walk the export graph from each entrypoint.
  const symbols = new Map<string, { decl: Declaration; file: string; entrypoints: Set<string> }>();
  const entrypoints: EntrypointInfo[] = [];
  const libraryCache = new Map<string, ReturnType<typeof parseLibrary>>();
  const library = (file: string): ReturnType<typeof parseLibrary> => {
    let parsed = libraryCache.get(file);
    if (parsed === undefined) {
      parsed = parseLibrary(read(file));
      libraryCache.set(file, parsed);
    }
    return parsed;
  };

  for (const entry of ENTRYPOINTS) {
    const uri = `package:${netKit.package}/${entry.file.replace(/^lib\//, '')}`;
    const reexports = new Set<string>();
    const visit = (
      file: string,
      show: Set<string> | null,
      hide: Set<string>,
      seen: Set<string>,
    ): void => {
      const key = `${file}|${show === null ? '*' : [...show].sort().join(',')}|${[...hide].sort().join(',')}`;
      if (seen.has(key)) return;
      seen.add(key);
      const lib = library(file);
      const decls = [...lib.declarations];
      for (const part of lib.parts) {
        decls.push(...library(toPosix(join(dirname(file), part))).declarations);
      }
      for (const decl of decls) {
        if ((show !== null && !show.has(decl.name)) || hide.has(decl.name)) continue;
        const existing = symbols.get(decl.name);
        if (existing === undefined) {
          symbols.set(decl.name, { decl, file, entrypoints: new Set([uri]) });
        } else {
          existing.entrypoints.add(uri);
        }
      }
      for (const directive of lib.exports) {
        if (directive.uri.startsWith('package:')) {
          reexports.add(directive.uri);
          continue;
        }
        if (directive.uri.startsWith('dart:')) continue;
        const target = toPosix(posix.normalize(posix.join(posix.dirname(file), directive.uri)));
        let nextShow = show;
        if (directive.show !== null) {
          const own = new Set(directive.show);
          nextShow = show === null ? own : new Set([...show].filter((n) => own.has(n)));
        }
        visit(target, nextShow, new Set([...hide, ...directive.hide]), seen);
      }
    };
    visit(entry.file, null, new Set(), new Set());
    entrypoints.push({ uri, description: entry.description, reexports: [...reexports].sort() });
  }

  const apiSymbols: ApiSymbol[] = [...symbols.values()]
    .map(({ decl, file, entrypoints: eps }) => ({
      name: decl.name,
      kind: decl.kind,
      signature: decl.signature,
      doc: decl.doc,
      deprecated: decl.deprecated,
      entrypoints: [...eps].sort(),
      source: { file, line: decl.line },
      members: decl.members,
    }))
    .sort((a, b) => a.name.localeCompare(b.name));

  const docs: DocEntry[] = DOC_SPECS.map((spec) => ({
    id: spec.id,
    title: spec.title,
    category: spec.category,
    source: toPosix(relative(join(netKitRoot, '..', '..'), join(netKitRoot, spec.file))),
    sections: splitSections(spec.id, spec.title, read(spec.file)),
  }));

  return { formatVersion: 1, netKit, entrypoints, symbols: apiSymbols, docs };
}

/** Stable JSON text for the artifact. */
export function serializeKnowledge(artifact: KnowledgeArtifact): string {
  return `${JSON.stringify(artifact, null, 2)}\n`;
}
