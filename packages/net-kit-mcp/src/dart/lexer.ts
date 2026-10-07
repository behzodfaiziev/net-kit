/**
 * Minimal Dart lexer.
 *
 * Produces the token stream the knowledge extractor and the semantic
 * analyzer work on. It understands everything that changes the meaning of
 * the surrounding text — line, block (nested) and doc comments, single,
 * double, triple-quoted and raw strings, and `$name` / `${expr}`
 * interpolation — so code inside comments or strings is never mistaken for
 * code. It does not build a syntax tree; callers do lightweight structural
 * matching over balanced brackets.
 *
 * Source text is treated purely as data: nothing here evaluates it.
 */

export type TokenKind = 'ident' | 'number' | 'string' | 'punct' | 'doc';

export interface Token {
  readonly kind: TokenKind;
  /** Exact source text of the token. */
  readonly text: string;
  /** For strings: the literal content without quotes; interpolations kept verbatim. */
  readonly value?: string;
  readonly start: number;
  readonly end: number;
  /** 1-based line and column of `start`. */
  readonly line: number;
  readonly column: number;
}

const MULTI_CHAR_PUNCT = [
  '...?',
  '?..',
  '...',
  '??=',
  '>>>',
  '..',
  '?.',
  '??',
  '=>',
  '==',
  '!=',
  '<=',
  '>=',
  '&&',
  '||',
  '++',
  '--',
  '+=',
  '-=',
  '*=',
  '/=',
  '%=',
  '&=',
  '|=',
  '^=',
  '~/',
];

function isIdentStart(ch: string): boolean {
  return /[A-Za-z_$]/.test(ch);
}

function isIdentPart(ch: string): boolean {
  return /[A-Za-z0-9_$]/.test(ch);
}

class LineIndex {
  private readonly starts: number[] = [0];

  constructor(source: string) {
    for (let i = 0; i < source.length; i++) {
      if (source.charCodeAt(i) === 10) {
        this.starts.push(i + 1);
      }
    }
  }

  position(offset: number): { line: number; column: number } {
    let low = 0;
    let high = this.starts.length - 1;
    while (low < high) {
      const mid = (low + high + 1) >> 1;
      if ((this.starts[mid] ?? 0) <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return { line: low + 1, column: offset - (this.starts[low] ?? 0) + 1 };
  }
}

/** Tokenizes [source]. Never throws: unterminated constructs end at EOF. */
export function tokenize(source: string): Token[] {
  const tokens: Token[] = [];
  const lines = new LineIndex(source);
  const length = source.length;
  let pos = 0;

  const push = (kind: TokenKind, start: number, end: number, value?: string): void => {
    const { line, column } = lines.position(start);
    const token: Token =
      value === undefined
        ? { kind, text: source.slice(start, end), start, end, line, column }
        : { kind, text: source.slice(start, end), value, start, end, line, column };
    tokens.push(token);
  };

  /** Skips a nested block comment starting at [from] (`/*`). Returns end offset. */
  const skipBlockComment = (from: number): number => {
    let depth = 0;
    let i = from;
    while (i < length) {
      if (source.startsWith('/*', i)) {
        depth++;
        i += 2;
      } else if (source.startsWith('*/', i)) {
        depth--;
        i += 2;
        if (depth === 0) {
          return i;
        }
      } else {
        i++;
      }
    }
    return length;
  };

  /**
   * Scans a string literal whose opening quote starts at [quoteStart].
   * Returns the end offset and the literal content.
   */
  const scanString = (quoteStart: number, raw: boolean): { end: number; value: string } => {
    const quote = source[quoteStart] ?? "'";
    const triple = source.startsWith(quote.repeat(3), quoteStart);
    const delimiter = triple ? quote.repeat(3) : quote;
    let i = quoteStart + delimiter.length;
    const contentStart = i;
    while (i < length) {
      if (source.startsWith(delimiter, i)) {
        return { end: i + delimiter.length, value: source.slice(contentStart, i) };
      }
      const ch = source[i];
      if (!triple && ch === '\n') {
        // Unterminated single-line string: stop at the line end.
        return { end: i, value: source.slice(contentStart, i) };
      }
      if (!raw && ch === '\\') {
        i += 2;
        continue;
      }
      if (!raw && ch === '$' && source[i + 1] === '{') {
        i = skipInterpolation(i + 2);
        continue;
      }
      i++;
    }
    return { end: length, value: source.slice(contentStart) };
  };

  /** Skips a `${...}` interpolation body starting after `${`. */
  const skipInterpolation = (from: number): number => {
    let depth = 1;
    let i = from;
    while (i < length && depth > 0) {
      const ch = source[i] ?? '';
      if (ch === '{') {
        depth++;
        i++;
      } else if (ch === '}') {
        depth--;
        i++;
      } else if (ch === "'" || ch === '"') {
        i = scanString(i, false).end;
      } else if ((ch === 'r' || ch === 'R') && (source[i + 1] === "'" || source[i + 1] === '"')) {
        i = scanString(i + 1, true).end;
      } else if (source.startsWith('//', i)) {
        const newline = source.indexOf('\n', i);
        i = newline < 0 ? length : newline;
      } else if (source.startsWith('/*', i)) {
        i = skipBlockComment(i);
      } else {
        i++;
      }
    }
    return i;
  };

  while (pos < length) {
    const ch = source[pos] ?? '';

    if (ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r' || ch === '\f') {
      pos++;
      continue;
    }

    if (source.startsWith('///', pos) && source[pos + 3] !== '/') {
      const newline = source.indexOf('\n', pos);
      const end = newline < 0 ? length : newline;
      push('doc', pos, end);
      pos = end;
      continue;
    }
    if (source.startsWith('//', pos)) {
      const newline = source.indexOf('\n', pos);
      pos = newline < 0 ? length : newline;
      continue;
    }
    if (source.startsWith('/**', pos) && !source.startsWith('/**/', pos)) {
      const end = skipBlockComment(pos);
      push('doc', pos, end);
      pos = end;
      continue;
    }
    if (source.startsWith('/*', pos)) {
      pos = skipBlockComment(pos);
      continue;
    }

    if ((ch === 'r' || ch === 'R') && (source[pos + 1] === "'" || source[pos + 1] === '"')) {
      const { end, value } = scanString(pos + 1, true);
      push('string', pos, end, value);
      pos = end;
      continue;
    }
    if (ch === "'" || ch === '"') {
      const { end, value } = scanString(pos, false);
      push('string', pos, end, value);
      pos = end;
      continue;
    }

    if (isIdentStart(ch)) {
      let end = pos + 1;
      while (end < length && isIdentPart(source[end] ?? '')) {
        end++;
      }
      push('ident', pos, end);
      pos = end;
      continue;
    }

    if (/[0-9]/.test(ch) || (ch === '.' && /[0-9]/.test(source[pos + 1] ?? ''))) {
      let end = pos + 1;
      while (end < length && /[0-9A-Za-z_.]/.test(source[end] ?? '')) {
        if (source[end] === '.' && !/[0-9]/.test(source[end + 1] ?? '')) {
          break;
        }
        end++;
      }
      push('number', pos, end);
      pos = end;
      continue;
    }

    const multi = MULTI_CHAR_PUNCT.find((op) => source.startsWith(op, pos));
    const end = pos + (multi?.length ?? 1);
    push('punct', pos, end);
    pos = end;
  }

  return tokens;
}

/** Tokens without doc comments, for structural matching. */
export function codeTokens(tokens: readonly Token[]): Token[] {
  return tokens.filter((token) => token.kind !== 'doc');
}

const OPENERS: Record<string, string> = { '(': ')', '[': ']', '{': '}' };

/**
 * Index of the bracket that closes the one at [openIndex], or the last
 * index when the source is unbalanced.
 */
export function matchingBracket(tokens: readonly Token[], openIndex: number): number {
  const open = tokens[openIndex]?.text ?? '';
  const close = OPENERS[open];
  if (close === undefined) {
    return openIndex;
  }
  let depth = 0;
  for (let i = openIndex; i < tokens.length; i++) {
    const text = tokens[i]?.text;
    if (text === open) {
      depth++;
    } else if (text === close) {
      depth--;
      if (depth === 0) {
        return i;
      }
    }
  }
  return tokens.length - 1;
}

/**
 * Joins tokens back into compact source text: tokens that were adjacent in
 * the source stay adjacent, anything separated by whitespace or comments is
 * separated by one space.
 */
export function joinTokens(tokens: readonly Token[]): string {
  let out = '';
  let previous: Token | undefined;
  for (const token of tokens) {
    if (previous !== undefined && token.start > previous.end) {
      out += ' ';
    }
    out += token.text;
    previous = token;
  }
  return out;
}
