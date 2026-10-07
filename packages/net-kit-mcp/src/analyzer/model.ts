import { codeTokens, joinTokens, matchingBracket, tokenize, type Token } from '../dart/lexer.js';

/**
 * Structural view of one Dart file for the semantic rules.
 *
 * Built from the token stream: call sites with their arguments, imports,
 * and the headers of enclosing blocks (`catch`, `if (...)`, named-argument
 * closures, method declarations). Comments and string contents can never be
 * mistaken for code. The model is static: no code is executed.
 */

export interface Argument {
  /** Named-argument label, or `null` for a positional argument. */
  readonly name: string | null;
  readonly tokens: readonly Token[];
  /** Compact source text of the value. */
  readonly text: string;
}

export interface CallSite {
  /** Called name: method, function, or constructor (`NetKitMultipartFile.fromBytes` → `fromBytes`). */
  readonly name: string;
  /** Identifier immediately before `.name`, if any (`manager` in `manager.requestVoid`). */
  readonly qualifier: string | null;
  /** True for `.name(`, `?.name(`, and `..name(`. */
  readonly isMember: boolean;
  /** Token index of the name. */
  readonly index: number;
  readonly openParen: number;
  readonly closeParen: number;
  readonly args: readonly Argument[];
  readonly line: number;
  readonly column: number;
  readonly endLine: number;
  readonly endColumn: number;
}

export interface BlockInfo {
  readonly open: number;
  readonly close: number;
  /** Tokens between the previous statement boundary and `{`. */
  readonly header: readonly Token[];
}

export interface DartFile {
  readonly path: string;
  readonly text: string;
  readonly tokens: readonly Token[];
  readonly imports: readonly string[];
  readonly calls: readonly CallSite[];
  readonly blocks: readonly BlockInfo[];
}

const KEYWORDS_NOT_CALLS = new Set([
  'if',
  'for',
  'while',
  'switch',
  'catch',
  'return',
  'assert',
  'super',
  'this',
  'await',
  'yield',
  'throw',
  'on',
  'when',
  'is',
  'as',
  'in',
  'new',
  'const',
  'final',
  'var',
  'late',
  'required',
  'Function',
]);

function splitArguments(tokens: readonly Token[], open: number, close: number): Argument[] {
  const args: Argument[] = [];
  let depth = 0;
  let start = open + 1;
  const flush = (end: number): void => {
    if (end <= start) return;
    const slice = tokens.slice(start, end);
    const first = slice[0];
    const second = slice[1];
    if (first?.kind === 'ident' && second?.text === ':' && slice.length > 2) {
      const value = slice.slice(2);
      args.push({ name: first.text, tokens: value, text: joinTokens(value) });
    } else {
      args.push({ name: null, tokens: slice, text: joinTokens(slice) });
    }
  };
  for (let i = open + 1; i < close; i++) {
    const text = tokens[i]?.text;
    if (text === '(' || text === '[' || text === '{') {
      depth++;
    } else if (text === ')' || text === ']' || text === '}') {
      depth--;
    } else if (text === ',' && depth === 0) {
      flush(i);
      start = i + 1;
    }
  }
  flush(close);
  return args;
}

/** Skips generic type arguments `<...>` ending just before index [paren]. */
function genericStart(tokens: readonly Token[], beforeParen: number): number {
  if (tokens[beforeParen]?.text !== '>') return beforeParen + 1;
  let depth = 0;
  for (let i = beforeParen; i >= 0; i--) {
    const text = tokens[i]?.text;
    if (text === '>') depth++;
    else if (text === '<') {
      depth--;
      if (depth === 0) return i;
    } else if (text === ';' || text === '{' || text === '}') {
      break;
    }
  }
  return beforeParen + 1;
}

export function parseDartFile(path: string, text: string): DartFile {
  const tokens = codeTokens(tokenize(text));
  const imports: string[] = [];
  const calls: CallSite[] = [];
  const blocks: BlockInfo[] = [];

  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    if (token === undefined) continue;

    if ((token.text === 'import' || token.text === 'export') && tokens[i + 1]?.kind === 'string') {
      const uri = tokens[i + 1]?.value;
      if (uri !== undefined && token.text === 'import') imports.push(uri);
      continue;
    }

    if (token.text === '{') {
      let h = i - 1;
      while (h >= 0) {
        const t = tokens[h]?.text;
        if (t === ';' || t === '{' || t === '}') break;
        h--;
      }
      blocks.push({ open: i, close: matchingBracket(tokens, i), header: tokens.slice(h + 1, i) });
      continue;
    }

    if (token.text !== '(') continue;
    // Find the callee name before `(`, skipping generic arguments.
    const nameIndex = genericStart(tokens, i - 1) - 1;
    const nameToken = tokens[nameIndex];
    if (nameToken?.kind !== 'ident' || KEYWORDS_NOT_CALLS.has(nameToken.text)) continue;
    // A function declaration `void foo(...) {` is not a call.
    const before = tokens[nameIndex - 1];
    const close = matchingBracket(tokens, i);
    const after = tokens[close + 1]?.text;
    const looksLikeDeclaration =
      before !== undefined &&
      (before.kind === 'ident' || before.text === '>' || before.text === '?') &&
      !['return', 'await', 'new', 'const', 'throw', 'yield', 'else', 'in'].includes(before.text) &&
      (after === '{' || after === '=>' || after === 'async' || after === ';' || after === ':');
    if (looksLikeDeclaration && before.text !== '.') continue;

    const isMember =
      before?.text === '.' ||
      before?.text === '?.' ||
      before?.text === '..' ||
      before?.text === '?..';
    const qualifierToken = isMember ? tokens[nameIndex - 2] : undefined;
    const end = tokens[close];
    calls.push({
      name: nameToken.text,
      qualifier: qualifierToken?.kind === 'ident' ? qualifierToken.text : null,
      isMember,
      index: nameIndex,
      openParen: i,
      closeParen: close,
      args: splitArguments(tokens, i, close),
      line: nameToken.line,
      column: nameToken.column,
      endLine: end?.line ?? nameToken.line,
      endColumn: (end?.column ?? nameToken.column) + 1,
    });
  }

  return { path, text, tokens, imports, calls, blocks };
}

/** Named argument of [call], if present. */
export function namedArg(call: CallSite, name: string): Argument | undefined {
  return call.args.find((arg) => arg.name === name);
}

/** Blocks enclosing token [index], innermost first. */
export function enclosingBlocks(file: DartFile, index: number): BlockInfo[] {
  return file.blocks
    .filter((block) => block.open < index && index < block.close)
    .sort((a, b) => b.open - a.open);
}

/** String literal values among [tokens]. */
export function stringValues(tokens: readonly Token[]): string[] {
  return tokens.filter((t) => t.kind === 'string').map((t) => t.value ?? '');
}

/** Identifier texts among [tokens]. */
export function identifiers(tokens: readonly Token[]): string[] {
  return tokens.filter((t) => t.kind === 'ident').map((t) => t.text);
}

/** Source text of the statement containing token [index] (bounded). */
export function statementText(file: DartFile, index: number): string {
  let start = index;
  while (start > 0) {
    const t = file.tokens[start - 1]?.text;
    if (t === ';' || t === '{' || t === '}') break;
    start--;
  }
  let end = index;
  let depth = 0;
  while (end < file.tokens.length - 1) {
    const t = file.tokens[end]?.text;
    if (t === '(' || t === '[' || t === '{') depth++;
    else if (t === ')' || t === ']' || t === '}') depth--;
    if (depth <= 0 && t === ';') break;
    end++;
  }
  return joinTokens(file.tokens.slice(start, end + 1));
}

/** Compact source of a call, truncated for display. */
export function callText(file: DartFile, call: CallSite, max = 400): string {
  let start = call.index;
  if (call.isMember && call.qualifier !== null) start = call.index - 2;
  const text = joinTokens(file.tokens.slice(start, call.closeParen + 1));
  return text.length > max ? `${text.slice(0, max)}…` : text;
}
