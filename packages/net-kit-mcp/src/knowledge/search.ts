/**
 * Small deterministic BM25 index. Works offline, has no dependencies, and
 * is rebuilt in memory once per process.
 */

export interface SearchDocument<T> {
  readonly key: string;
  /** Weighted text fields: [text, weight]. */
  readonly fields: readonly (readonly [string, number])[];
  readonly payload: T;
}

export interface SearchHit<T> {
  readonly key: string;
  readonly score: number;
  readonly payload: T;
}

const STOP_WORDS = new Set([
  'a',
  'an',
  'and',
  'are',
  'as',
  'at',
  'be',
  'by',
  'do',
  'does',
  'for',
  'from',
  'how',
  'i',
  'in',
  'is',
  'it',
  'of',
  'on',
  'or',
  'should',
  'that',
  'the',
  'this',
  'to',
  'use',
  'what',
  'when',
  'which',
  'with',
  'my',
  'can',
  'via',
]);

/** Lower-case terms; camelCase and snake_case identifiers also yield their parts. */
export function terms(text: string): string[] {
  const out: string[] = [];
  for (const raw of text.match(/[A-Za-z0-9_]+/g) ?? []) {
    const lower = raw.toLowerCase();
    if (!STOP_WORDS.has(lower) && lower.length > 1) {
      out.push(lower);
    }
    const parts = raw
      .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
      .replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2')
      .split(/[\s_]+/)
      .map((p) => p.toLowerCase())
      .filter((p) => p.length > 1 && !STOP_WORDS.has(p));
    if (parts.length > 1) {
      out.push(...parts);
    }
  }
  return out;
}

export class SearchIndex<T> {
  private readonly docs: { key: string; payload: T; tf: Map<string, number>; length: number }[] =
    [];
  private readonly df = new Map<string, number>();
  private averageLength = 1;

  constructor(documents: readonly SearchDocument<T>[]) {
    let total = 0;
    for (const document of documents) {
      const tf = new Map<string, number>();
      let length = 0;
      for (const [text, weight] of document.fields) {
        for (const term of terms(text)) {
          tf.set(term, (tf.get(term) ?? 0) + weight);
          length += weight;
        }
      }
      for (const term of tf.keys()) {
        this.df.set(term, (this.df.get(term) ?? 0) + 1);
      }
      this.docs.push({ key: document.key, payload: document.payload, tf, length });
      total += length;
    }
    this.averageLength = this.docs.length === 0 ? 1 : total / this.docs.length;
  }

  search(query: string, limit: number, filter?: (payload: T) => boolean): SearchHit<T>[] {
    const queryTerms = [...new Set(terms(query))];
    if (queryTerms.length === 0) {
      return [];
    }
    const k1 = 1.2;
    const b = 0.75;
    const n = this.docs.length;
    const hits: SearchHit<T>[] = [];
    for (const doc of this.docs) {
      if (filter !== undefined && !filter(doc.payload)) {
        continue;
      }
      let score = 0;
      for (const term of queryTerms) {
        const frequency = doc.tf.get(term);
        if (frequency === undefined) continue;
        const df = this.df.get(term) ?? 0;
        const idf = Math.log(1 + (n - df + 0.5) / (df + 0.5));
        score +=
          (idf * frequency * (k1 + 1)) /
          (frequency + k1 * (1 - b + (b * doc.length) / this.averageLength));
      }
      if (score > 0) {
        hits.push({ key: doc.key, score, payload: doc.payload });
      }
    }
    hits.sort((a, b2) => b2.score - a.score || a.key.localeCompare(b2.key));
    return hits.slice(0, limit);
  }
}

/** A short excerpt of [text] around the first query term it contains. */
export function excerpt(text: string, query: string, size = 280): string {
  const clean = text.replace(/\s+/g, ' ').trim();
  if (clean.length <= size) {
    return clean;
  }
  const lower = clean.toLowerCase();
  let at = -1;
  for (const term of terms(query)) {
    const index = lower.indexOf(term);
    if (index >= 0 && (at < 0 || index < at)) {
      at = index;
    }
  }
  const start = Math.max(0, Math.min(at < 0 ? 0 : at - size / 3, clean.length - size));
  const prefix = start > 0 ? '…' : '';
  const suffix = start + size < clean.length ? '…' : '';
  return `${prefix}${clean.slice(start, start + size).trim()}${suffix}`;
}
