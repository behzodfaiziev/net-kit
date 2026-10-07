import type { DartFile } from './model.js';

export type Severity = 'info' | 'warning' | 'error';
export type Confidence = 'high' | 'medium' | 'low';
export type RuleCategory =
  'auth' | 'refresh' | 'upload' | 'streaming' | 'migration' | 'configuration' | 'transport';

export interface Range {
  readonly startLine: number;
  readonly startColumn: number;
  readonly endLine: number;
  readonly endColumn: number;
}

/** A suggested change. It is text only; the server never applies it. */
export interface Suggestion {
  readonly label: 'SUGGESTED — NOT APPLIED';
  readonly currentPattern: string;
  readonly suggestedPattern: string;
  readonly explanation: string;
}

export interface Finding {
  readonly ruleId: string;
  readonly title: string;
  readonly severity: Severity;
  readonly confidence: Confidence;
  /** Path relative to the authorized root. */
  readonly file: string;
  readonly range: Range;
  readonly message: string;
  readonly recommendation: string;
  readonly resources: readonly string[];
  readonly suggestion?: Suggestion;
}

export interface RuleInfo {
  readonly id: string;
  readonly title: string;
  readonly categories: readonly RuleCategory[];
  readonly description: string;
}

/** Facts about the inspected project gathered before rules run. */
export interface ProjectFacts {
  /** `net_kit` dependency constraint from pubspec.yaml, if declared. */
  readonly netKitConstraint: string | null;
  /** Resolved `net_kit` version from pubspec.lock, if present. */
  readonly resolvedNetKitVersion: string | null;
  /** Major version the project targets: 6, 5, or null when unknown. */
  readonly targetMajor: number | null;
  /** Hosts of literal `baseUrl`/`devBaseUrl` values passed to `NetKitManager`. */
  readonly apiHosts: readonly string[];
  /** Whether any manager configures `refreshTokenPath`. */
  readonly usesRefresh: boolean;
}

export interface RuleContext {
  readonly files: readonly DartFile[];
  readonly facts: ProjectFacts;
}

export type Rule = RuleInfo & {
  readonly run: (context: RuleContext) => Finding[];
};
