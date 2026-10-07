import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { packageRoot } from '../util/packageRoot.js';
import { excerpt, SearchIndex } from './search.js';
import type { ApiSymbol, DocCategory, DocEntry, DocSection, KnowledgeArtifact } from './types.js';

export type SearchArea = 'api' | 'docs' | 'migration' | 'security' | 'examples';

export const SEARCH_AREAS: readonly SearchArea[] = [
  'api',
  'docs',
  'migration',
  'security',
  'examples',
];

export interface KnowledgeMatch {
  readonly kind: 'symbol' | 'section';
  readonly title: string;
  readonly area: SearchArea;
  readonly excerpt: string;
  readonly resource: string;
  readonly source: string;
  readonly score: number;
}

type Indexed =
  | { readonly kind: 'symbol'; readonly symbol: ApiSymbol }
  | { readonly kind: 'section'; readonly doc: DocEntry; readonly section: DocSection };

const AREA_BY_CATEGORY: Record<DocCategory, SearchArea> = {
  docs: 'docs',
  changelog: 'docs',
  auth: 'security',
  security: 'security',
  migration: 'migration',
  examples: 'examples',
};

/** Resource URI of a public symbol. */
export function apiUri(name: string): string {
  return `netkit://api/${encodeURIComponent(name)}`;
}

/** Resource URI of a document or one of its sections. */
export function docUri(id: string): string {
  return `netkit://docs/${encodeURIComponent(id)}`;
}

/**
 * Immutable, in-memory view of the generated knowledge artifact.
 *
 * Source-derived API metadata answers "what exists"; the curated documents
 * answer "how to use it". Both come from the same artifact so every answer
 * carries the net_kit version it was generated from.
 */
export class KnowledgeBase {
  private readonly symbolsByName = new Map<string, ApiSymbol>();
  private readonly symbolsByLowerName = new Map<string, ApiSymbol>();
  private readonly docsById = new Map<string, DocEntry>();
  private readonly sectionsById = new Map<string, { doc: DocEntry; section: DocSection }>();
  private index: SearchIndex<Indexed> | undefined;

  constructor(readonly artifact: KnowledgeArtifact) {
    for (const symbol of artifact.symbols) {
      this.symbolsByName.set(symbol.name, symbol);
      this.symbolsByLowerName.set(symbol.name.toLowerCase(), symbol);
    }
    for (const doc of artifact.docs) {
      this.docsById.set(doc.id, doc);
      for (const section of doc.sections) {
        this.sectionsById.set(section.id, { doc, section });
      }
    }
  }

  /** Loads the artifact shipped with this package. */
  static load(file = join(packageRoot(), 'generated', 'netkit-knowledge.json')): KnowledgeBase {
    return new KnowledgeBase(JSON.parse(readFileSync(file, 'utf8')) as KnowledgeArtifact);
  }

  get version(): string {
    return this.artifact.netKit.version;
  }

  get symbols(): readonly ApiSymbol[] {
    return this.artifact.symbols;
  }

  get docs(): readonly DocEntry[] {
    return this.artifact.docs;
  }

  /** Exact (then case-insensitive) symbol lookup. */
  symbol(name: string): ApiSymbol | undefined {
    return this.symbolsByName.get(name) ?? this.symbolsByLowerName.get(name.toLowerCase());
  }

  /** Public symbols whose names resemble [name], best first. */
  similarSymbols(name: string, limit = 5): string[] {
    const target = name.toLowerCase();
    return this.artifact.symbols
      .map((s) => ({ name: s.name, distance: editDistance(target, s.name.toLowerCase()) }))
      .filter(
        (s) =>
          s.distance <= Math.max(3, Math.floor(target.length / 2)) ||
          s.name.toLowerCase().includes(target),
      )
      .sort((a, b) => a.distance - b.distance || a.name.localeCompare(b.name))
      .slice(0, limit)
      .map((s) => s.name);
  }

  doc(id: string): DocEntry | undefined {
    return this.docsById.get(id);
  }

  section(id: string): { doc: DocEntry; section: DocSection } | undefined {
    return this.sectionsById.get(id);
  }

  search(
    query: string,
    limit: number,
    areas: readonly SearchArea[] = SEARCH_AREAS,
  ): KnowledgeMatch[] {
    this.index ??= this.buildIndex();
    const allowed = new Set(areas);
    return this.index
      .search(query, limit, (item) => allowed.has(areaOf(item)))
      .map((hit) => {
        const item = hit.payload;
        if (item.kind === 'symbol') {
          return {
            kind: 'symbol' as const,
            title: item.symbol.name,
            area: 'api' as const,
            excerpt: excerpt(`${item.symbol.signature}. ${item.symbol.doc}`, query),
            resource: apiUri(item.symbol.name),
            source: `packages/net-kit/${item.symbol.source.file}`,
            score: round(hit.score),
          };
        }
        return {
          kind: 'section' as const,
          title: item.section.path.join(' › '),
          area: AREA_BY_CATEGORY[item.doc.category],
          excerpt: excerpt(item.section.text, query),
          resource: docUri(item.section.id),
          source: item.doc.source,
          score: round(hit.score),
        };
      });
  }

  private buildIndex(): SearchIndex<Indexed> {
    const documents = [
      ...this.artifact.symbols.map((symbol) => ({
        key: `api:${symbol.name}`,
        fields: [
          [symbol.name, 6],
          [symbol.signature, 2],
          [symbol.doc, 1],
          [symbol.members.map((m) => `${m.name} ${m.doc}`).join(' '), 1],
        ] as const,
        payload: { kind: 'symbol' as const, symbol },
      })),
      ...this.artifact.docs.flatMap((doc) =>
        doc.sections.map((section) => ({
          key: `doc:${section.id}`,
          fields: [
            [section.heading, 4],
            [section.path.join(' '), 1],
            [section.text, 1],
          ] as const,
          payload: { kind: 'section' as const, doc, section },
        })),
      ),
    ];
    return new SearchIndex<Indexed>(documents);
  }
}

function areaOf(item: Indexed): SearchArea {
  return item.kind === 'symbol' ? 'api' : AREA_BY_CATEGORY[item.doc.category];
}

function round(value: number): number {
  return Math.round(value * 1000) / 1000;
}

function editDistance(a: string, b: string): number {
  const row = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    let previous = row[0] ?? 0;
    row[0] = i;
    for (let j = 1; j <= b.length; j++) {
      const current = row[j] ?? 0;
      row[j] = Math.min(
        (row[j] ?? 0) + 1,
        (row[j - 1] ?? 0) + 1,
        previous + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
      previous = current;
    }
  }
  return row[b.length] ?? 0;
}
