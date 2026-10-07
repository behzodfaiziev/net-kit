/**
 * Shape of the generated knowledge artifact (`generated/netkit-knowledge.json`).
 *
 * The artifact is produced from the net_kit package source and its public
 * documentation by `generate-knowledge`. It contains no absolute paths: every
 * `source` is relative to the net_kit package root (or the repository root
 * for repository-level documentation).
 */

export type ApiSymbolKind =
  | 'class'
  | 'abstract class'
  | 'interface class'
  | 'sealed class'
  | 'final class'
  | 'mixin'
  | 'enum'
  | 'extension'
  | 'typedef'
  | 'function'
  | 'variable';

export type ApiMemberKind =
  'constructor' | 'factory' | 'method' | 'getter' | 'setter' | 'field' | 'enum value' | 'operator';

export interface ApiMember {
  readonly name: string;
  readonly kind: ApiMemberKind;
  readonly signature: string;
  readonly doc: string;
  readonly isStatic: boolean;
  readonly isOverride: boolean;
  readonly deprecated: string | null;
  readonly visibleForTesting: boolean;
}

export interface ApiSymbol {
  readonly name: string;
  readonly kind: ApiSymbolKind;
  /** Declaration header, e.g. `final class FileRawHttpBody extends RawHttpBody`. */
  readonly signature: string;
  readonly doc: string;
  readonly deprecated: string | null;
  /** Entrypoints that make the symbol visible, e.g. `package:net_kit/net_kit.dart`. */
  readonly entrypoints: readonly string[];
  /** Source file relative to the net_kit package root, with the 1-based line. */
  readonly source: { readonly file: string; readonly line: number };
  readonly members: readonly ApiMember[];
}

export interface DocSection {
  /** Stable id: `<docId>.<slug>`. */
  readonly id: string;
  readonly docId: string;
  readonly heading: string;
  /** Heading path from the document title to this section. */
  readonly path: readonly string[];
  readonly level: number;
  readonly text: string;
}

export type DocCategory = 'docs' | 'auth' | 'migration' | 'examples' | 'security' | 'changelog';

export interface DocEntry {
  readonly id: string;
  readonly title: string;
  readonly category: DocCategory;
  /** Path relative to the repository root, e.g. `packages/net-kit/README.md`. */
  readonly source: string;
  readonly sections: readonly DocSection[];
}

export interface EntrypointInfo {
  readonly uri: string;
  readonly description: string;
  /** Third-party libraries the entrypoint re-exports wholesale. */
  readonly reexports: readonly string[];
}

export interface KnowledgeArtifact {
  readonly formatVersion: 1;
  readonly netKit: {
    readonly package: string;
    readonly version: string;
    readonly sdkConstraint: string;
    readonly dependencies: Readonly<Record<string, string>>;
  };
  readonly entrypoints: readonly EntrypointInfo[];
  readonly symbols: readonly ApiSymbol[];
  readonly docs: readonly DocEntry[];
}
