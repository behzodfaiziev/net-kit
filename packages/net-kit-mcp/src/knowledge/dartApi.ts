import { joinTokens, matchingBracket, tokenize, type Token } from '../dart/lexer.js';
import type { ApiMember, ApiMemberKind, ApiSymbolKind } from './types.js';

/**
 * Structural reader for Dart library files, used to derive the public API
 * of net_kit from its source.
 *
 * It recognises top-level declarations and their members well enough to
 * report names, kinds, signatures, Dartdoc and deprecation, which is all the
 * knowledge layer needs. It is not a general Dart parser.
 */

export interface ExportDirective {
  readonly uri: string;
  readonly show: readonly string[] | null;
  readonly hide: readonly string[];
}

export interface Declaration {
  readonly name: string;
  readonly kind: ApiSymbolKind;
  readonly signature: string;
  readonly doc: string;
  readonly deprecated: string | null;
  readonly line: number;
  readonly members: readonly ApiMember[];
}

export interface LibraryInfo {
  readonly exports: readonly ExportDirective[];
  readonly parts: readonly string[];
  readonly declarations: readonly Declaration[];
}

interface Annotations {
  deprecated: string | null;
  visibleForTesting: boolean;
  isOverride: boolean;
}

const CLASS_MODIFIERS = new Set(['abstract', 'sealed', 'final', 'base', 'interface', 'mixin']);
const MEMBER_MODIFIERS = new Set([
  'static',
  'final',
  'const',
  'late',
  'external',
  'covariant',
  'abstract',
]);

export function docText(docTokens: readonly Token[]): string {
  const lines: string[] = [];
  for (const token of docTokens) {
    if (token.text.startsWith('///')) {
      lines.push(token.text.slice(3).replace(/^ /, ''));
    } else {
      const body = token.text.replace(/^\/\*\*/, '').replace(/\*\/$/, '');
      for (const raw of body.split('\n')) {
        lines.push(raw.replace(/^\s*\* ?/, '').trimEnd());
      }
    }
  }
  return lines.join('\n').trim();
}

/** Parses an annotation starting at `@`; returns the index after it. */
function readAnnotation(tokens: readonly Token[], at: number, into: Annotations): number {
  let i = at + 1;
  const nameParts: string[] = [];
  while (i < tokens.length && tokens[i]?.kind === 'ident') {
    nameParts.push(tokens[i]?.text ?? '');
    if (tokens[i + 1]?.text === '.') {
      i += 2;
    } else {
      i++;
      break;
    }
  }
  const name = nameParts.join('.');
  let argsEnd = i - 1;
  if (tokens[i]?.text === '(') {
    argsEnd = matchingBracket(tokens, i);
  }
  if (name === 'Deprecated') {
    const message = tokens.slice(i, argsEnd + 1).find((t) => t.kind === 'string');
    into.deprecated = message?.value ?? 'Deprecated';
  } else if (name === 'deprecated') {
    into.deprecated = 'Deprecated';
  } else if (name === 'visibleForTesting') {
    into.visibleForTesting = true;
  } else if (name === 'override') {
    into.isOverride = true;
  }
  return argsEnd + 1;
}

function emptyAnnotations(): Annotations {
  return { deprecated: null, visibleForTesting: false, isOverride: false };
}

/**
 * Finds where a declaration header ends: the first `;`, `{` or `=>` that is
 * not nested in parentheses or brackets, starting at [from].
 */
function headerEnd(tokens: readonly Token[], from: number, limit: number): number {
  let depth = 0;
  for (let i = from; i < limit; i++) {
    const text = tokens[i]?.text;
    if (text === '(' || text === '[') {
      depth++;
    } else if (text === ')' || text === ']') {
      depth--;
    } else if (depth === 0 && (text === ';' || text === '{' || text === '=>')) {
      return i;
    }
  }
  return limit;
}

/** End index (inclusive) of the declaration whose header ends at [end]. */
function declarationEnd(tokens: readonly Token[], end: number, limit: number): number {
  const text = tokens[end]?.text;
  if (text === '{') {
    return matchingBracket(tokens, end);
  }
  if (text === '=>') {
    let depth = 0;
    for (let i = end + 1; i < limit; i++) {
      const t = tokens[i]?.text;
      if (t === '(' || t === '[' || t === '{') {
        depth++;
      } else if (t === ')' || t === ']' || t === '}') {
        depth--;
      } else if (t === ';' && depth === 0) {
        return i;
      }
    }
    return limit - 1;
  }
  return end;
}

const LITERAL_BRACE_PREDECESSORS = new Set([
  '=',
  ',',
  ':',
  '(',
  '[',
  '?',
  '??',
  '=>',
  '||',
  '&&',
  '>',
  'const',
  'return',
]);

/**
 * End index (inclusive) of a constructor whose initializer list starts at
 * [from]: a top-level `;`, the end of an `=>` body, or the closing brace of
 * a block body. Braces that open a collection literal are skipped.
 */
function initializerListEnd(tokens: readonly Token[], from: number, limit: number): number {
  let depth = 0;
  for (let i = from; i < limit; i++) {
    const text = tokens[i]?.text;
    if (text === '(' || text === '[') {
      depth++;
    } else if (text === ')' || text === ']') {
      depth--;
    } else if (depth === 0 && text === ';') {
      return i;
    } else if (depth === 0 && text === '=>') {
      return declarationEnd(tokens, i, limit);
    } else if (text === '{') {
      const previous = tokens[i - 1]?.text ?? '';
      const close = matchingBracket(tokens, i);
      if (depth > 0 || LITERAL_BRACE_PREDECESSORS.has(previous)) {
        i = close;
      } else {
        return close;
      }
    }
  }
  return limit - 1;
}

/** Index of the first top-level occurrence of [text] in [from, to). */
function findTopLevel(tokens: readonly Token[], text: string, from: number, to: number): number {
  let depth = 0;
  for (let i = from; i < to; i++) {
    const t = tokens[i]?.text;
    if (depth === 0 && t === text) {
      return i;
    }
    if (t === '(' || t === '[' || t === '{') {
      depth++;
    } else if (t === ')' || t === ']' || t === '}') {
      depth--;
    }
  }
  return -1;
}

function parseCombinatorList(tokens: readonly Token[], from: number, to: number): string[] {
  const names: string[] = [];
  for (let i = from; i < to; i++) {
    const token = tokens[i];
    if (token?.kind === 'ident' && token.text !== 'show' && token.text !== 'hide') {
      names.push(token.text);
    } else if (token?.text === 'show' || token?.text === 'hide') {
      break;
    }
  }
  return names;
}

function parseDirective(
  tokens: readonly Token[],
  at: number,
  end: number,
  exports: ExportDirective[],
  parts: string[],
): void {
  const keyword = tokens[at]?.text;
  const uri = tokens.slice(at, end).find((t) => t.kind === 'string')?.value;
  if (uri === undefined) {
    return;
  }
  if (keyword === 'part' && tokens[at + 1]?.text !== 'of') {
    parts.push(uri);
    return;
  }
  if (keyword !== 'export') {
    return;
  }
  let show: string[] | null = null;
  const hide: string[] = [];
  for (let i = at; i < end; i++) {
    const text = tokens[i]?.text;
    if (text === 'show') {
      show = [...(show ?? []), ...parseCombinatorList(tokens, i + 1, end)];
    } else if (text === 'hide') {
      hide.push(...parseCombinatorList(tokens, i + 1, end));
    }
  }
  exports.push({ uri, show, hide });
}

function classKind(modifiers: readonly string[]): ApiSymbolKind {
  if (modifiers.includes('sealed')) return 'sealed class';
  if (modifiers.includes('abstract') && modifiers.includes('interface')) return 'interface class';
  if (modifiers.includes('abstract')) return 'abstract class';
  if (modifiers.includes('interface')) return 'interface class';
  if (modifiers.includes('final')) return 'final class';
  return 'class';
}

/** Name of the identifier before the first top-level `(`, skipping generics. */
function nameBeforeParen(tokens: readonly Token[], from: number, to: number): string | null {
  const paren = findTopLevel(tokens, '(', from, to);
  if (paren < 0) {
    return null;
  }
  let i = paren - 1;
  if (tokens[i]?.text === '>') {
    let depth = 0;
    for (; i >= from; i--) {
      const t = tokens[i]?.text;
      if (t === '>') depth++;
      else if (t === '<') {
        depth--;
        if (depth === 0) {
          i--;
          break;
        }
      }
    }
  }
  const token = tokens[i];
  return token?.kind === 'ident' ? token.text : null;
}

function parseMembers(
  tokens: readonly Token[],
  open: number,
  close: number,
  className: string,
  isEnum: boolean,
): ApiMember[] {
  const members: ApiMember[] = [];
  let i = open + 1;

  if (isEnum) {
    // Enum values run until the first top-level `;` (or the closing brace).
    let docs: Token[] = [];
    let annotations = emptyAnnotations();
    let expectValue = true;
    while (i < close) {
      const token = tokens[i];
      if (token === undefined) break;
      if (token.kind === 'doc') {
        docs.push(token);
        i++;
        continue;
      }
      if (token.text === '@') {
        i = readAnnotation(tokens, i, annotations);
        continue;
      }
      if (token.text === ';') {
        i++;
        break;
      }
      if (token.text === ',') {
        expectValue = true;
        i++;
        continue;
      }
      if (token.text === '(') {
        i = matchingBracket(tokens, i) + 1;
        continue;
      }
      if (expectValue && token.kind === 'ident') {
        members.push({
          name: token.text,
          kind: 'enum value',
          signature: `${className}.${token.text}`,
          doc: docText(docs),
          isStatic: true,
          isOverride: false,
          deprecated: annotations.deprecated,
          visibleForTesting: annotations.visibleForTesting,
        });
        docs = [];
        annotations = emptyAnnotations();
        expectValue = false;
      }
      i++;
    }
  }

  let docs: Token[] = [];
  let annotations = emptyAnnotations();
  while (i < close) {
    const token = tokens[i];
    if (token === undefined) break;
    if (token.kind === 'doc') {
      docs.push(token);
      i++;
      continue;
    }
    if (token.text === '@') {
      i = readAnnotation(tokens, i, annotations);
      continue;
    }
    if (token.text === ';') {
      i++;
      continue;
    }

    const start = i;
    // A record return type, `(int, String) name(...)`, is not the parameter list.
    const searchFrom = token.text === '(' ? matchingBracket(tokens, start) + 1 : start;
    const assign = findTopLevel(tokens, '=', start, close);
    const firstParen = findTopLevel(tokens, '(', searchFrom, close);
    const semicolon = findTopLevel(tokens, ';', start, close);
    const beforeParen = firstParen > searchFrom ? tokens[firstParen - 1] : undefined;
    // `final void Function(Object) logPrint;` and record-typed fields.
    const functionTypedField =
      firstParen >= 0 &&
      (beforeParen?.text === 'Function' ||
        (beforeParen?.kind !== 'ident' && beforeParen?.text !== '>'));
    const isField =
      (firstParen < 0 ||
        (assign >= 0 && assign < firstParen) ||
        (semicolon >= 0 && semicolon < firstParen) ||
        functionTypedField) &&
      !tokens
        .slice(start, Math.max(start, semicolon < 0 ? close : semicolon))
        .some((t) => t.text === 'get' || t.text === 'set' || t.text === 'operator');

    let headerStop: number;
    let end: number;
    if (isField) {
      end = semicolon < 0 ? close - 1 : semicolon;
      headerStop = assign >= 0 && assign < end ? assign : end;
    } else {
      const paramsClose = firstParen >= 0 ? matchingBracket(tokens, firstParen) : -1;
      if (paramsClose >= 0 && tokens[paramsClose + 1]?.text === ':') {
        // Constructor with an initializer list: it may contain literals with
        // braces, so find the real end separately.
        headerStop = paramsClose + 1;
        end = initializerListEnd(tokens, paramsClose + 2, close);
      } else {
        const stop = headerEnd(tokens, start, close);
        end = declarationEnd(tokens, stop, close);
        headerStop = stop;
      }
    }

    const header = tokens.slice(start, headerStop).filter((t) => t.kind !== 'doc');
    const words = header.map((t) => t.text);
    const isStatic = words.includes('static');
    let name: string | null;
    let kind: ApiMemberKind;

    const core = header.filter((t) => !MEMBER_MODIFIERS.has(t.text));
    const first = core[0]?.text;
    if (first === 'factory') {
      kind = 'factory';
      name =
        core[2]?.text === '.'
          ? `${core[1]?.text ?? ''}.${core[3]?.text ?? ''}`
          : (core[1]?.text ?? null);
    } else if (first === className && (core[1]?.text === '(' || core[1]?.text === '.')) {
      kind = 'constructor';
      name = core[1].text === '.' ? `${className}.${core[2]?.text ?? ''}` : className;
    } else if (words.includes('get')) {
      kind = 'getter';
      name = header[words.indexOf('get') + 1]?.text ?? null;
    } else if (words.includes('set')) {
      kind = 'setter';
      name = header[words.indexOf('set') + 1]?.text ?? null;
    } else if (words.includes('operator')) {
      kind = 'operator';
      name = `operator ${header[words.indexOf('operator') + 1]?.text ?? ''}`;
    } else if (isField) {
      kind = 'field';
      const idents = header.filter((t) => t.kind === 'ident');
      name = idents[idents.length - 1]?.text ?? null;
    } else {
      kind = 'method';
      name = nameBeforeParen(tokens, searchFrom, headerStop);
    }

    const isPrivate =
      name === null || name.startsWith('_') || name.includes('._') || name.endsWith('.');
    if (name !== null && !isPrivate) {
      members.push({
        name,
        kind,
        signature: joinTokens(header),
        doc: docText(docs),
        isStatic,
        isOverride: annotations.isOverride,
        deprecated: annotations.deprecated,
        visibleForTesting: annotations.visibleForTesting,
      });
    }
    docs = [];
    annotations = emptyAnnotations();
    i = end + 1;
  }
  return members;
}

/** Parses one Dart library file. */
export function parseLibrary(source: string): LibraryInfo {
  const tokens = tokenize(source);
  const exports: ExportDirective[] = [];
  const parts: string[] = [];
  const declarations: Declaration[] = [];

  let docs: Token[] = [];
  let annotations = emptyAnnotations();
  let i = 0;
  while (i < tokens.length) {
    const token = tokens[i];
    if (token === undefined) break;
    if (token.kind === 'doc') {
      docs.push(token);
      i++;
      continue;
    }
    if (token.text === '@') {
      i = readAnnotation(tokens, i, annotations);
      continue;
    }
    if (['import', 'export', 'part', 'library'].includes(token.text)) {
      const end = findTopLevel(tokens, ';', i, tokens.length);
      const stop = end < 0 ? tokens.length : end;
      parseDirective(tokens, i, stop, exports, parts);
      docs = [];
      annotations = emptyAnnotations();
      i = stop + 1;
      continue;
    }
    if (token.text === ';') {
      i++;
      continue;
    }

    const start = i;
    const stop = headerEnd(tokens, start, tokens.length);
    const end = declarationEnd(tokens, stop, tokens.length);
    const header = tokens.slice(start, stop).filter((t) => t.kind !== 'doc');
    const words = header.map((t) => t.text);
    let declaration: Declaration;
    const base = {
      doc: docText(docs),
      deprecated: annotations.deprecated,
      line: token.line,
    };

    const classIndex = words.indexOf('class');
    if (classIndex >= 0) {
      const name = words[classIndex + 1] ?? '';
      const modifiers = words.slice(0, classIndex).filter((w) => CLASS_MODIFIERS.has(w));
      declaration = {
        ...base,
        name,
        kind: modifiers.includes('mixin') ? 'mixin' : classKind(modifiers),
        signature: joinTokens(header),
        members: tokens[stop]?.text === '{' ? parseMembers(tokens, stop, end, name, false) : [],
      };
    } else if (words[0] === 'mixin') {
      const name = words[1] ?? '';
      declaration = {
        ...base,
        name,
        kind: 'mixin',
        signature: joinTokens(header),
        members: tokens[stop]?.text === '{' ? parseMembers(tokens, stop, end, name, false) : [],
      };
    } else if (words[0] === 'enum') {
      const name = words[1] ?? '';
      declaration = {
        ...base,
        name,
        kind: 'enum',
        signature: joinTokens(header),
        members: tokens[stop]?.text === '{' ? parseMembers(tokens, stop, end, name, true) : [],
      };
    } else if (words[0] === 'extension') {
      const name = words[1] === 'on' || words[1] === 'type' ? '' : (words[1] ?? '');
      declaration = {
        ...base,
        name,
        kind: 'extension',
        signature: joinTokens(header),
        members: tokens[stop]?.text === '{' ? parseMembers(tokens, stop, end, name, false) : [],
      };
    } else if (words[0] === 'typedef') {
      const name =
        words[2] === '=' || words[2] === '<'
          ? (words[1] ?? '')
          : nameBeforeParen(tokens, start, stop);
      const full = tokens.slice(start, end).filter((t) => t.kind !== 'doc');
      declaration = {
        ...base,
        name: name ?? '',
        kind: 'typedef',
        signature: joinTokens(full),
        members: [],
      };
    } else {
      const assign = findTopLevel(tokens, '=', start, stop);
      const paren = findTopLevel(tokens, '(', start, stop);
      if (paren >= 0 && (assign < 0 || paren < assign)) {
        declaration = {
          ...base,
          name: nameBeforeParen(tokens, start, stop) ?? '',
          kind: 'function',
          signature: joinTokens(header),
          members: [],
        };
      } else {
        const limit = assign >= 0 ? assign : stop;
        const idents = tokens.slice(start, limit).filter((t) => t.kind === 'ident');
        declaration = {
          ...base,
          name: idents[idents.length - 1]?.text ?? '',
          kind: 'variable',
          signature: joinTokens(tokens.slice(start, limit).filter((t) => t.kind !== 'doc')),
          members: [],
        };
      }
    }

    if (declaration.name !== '' && !declaration.name.startsWith('_')) {
      declarations.push(declaration);
    }
    docs = [];
    annotations = emptyAnnotations();
    i = end + 1;
  }

  return { exports, parts, declarations };
}
