import type { KnowledgeBase } from './knowledgeBase.js';
import { apiUri, docUri } from './knowledgeBase.js';
import type { ApiSymbol, DocEntry, DocSection } from './types.js';

/** Markdown rendering of knowledge for resources and tool text. */

export function renderSymbol(kb: KnowledgeBase, symbol: ApiSymbol): string {
  const lines = [
    `# ${symbol.name}`,
    '',
    `net_kit version: ${kb.version}`,
    `Kind: ${symbol.kind}`,
    `Entrypoints: ${symbol.entrypoints.map((e) => `\`${e}\``).join(', ')}`,
    `Source: packages/net-kit/${symbol.source.file}:${symbol.source.line}`,
  ];
  if (symbol.deprecated !== null) {
    lines.push(`Deprecated: ${symbol.deprecated}`);
  }
  lines.push('', '```dart', symbol.signature, '```');
  if (symbol.doc !== '') {
    lines.push('', symbol.doc);
  }
  const groups: [string, (k: string) => boolean][] = [
    ['Enum values', (k) => k === 'enum value'],
    ['Constructors', (k) => k === 'constructor' || k === 'factory'],
    ['Properties', (k) => k === 'field' || k === 'getter' || k === 'setter'],
    ['Methods', (k) => k === 'method' || k === 'operator'],
  ];
  for (const [title, matches] of groups) {
    const members = symbol.members.filter((m) => matches(m.kind));
    if (members.length === 0) continue;
    lines.push('', `## ${title}`);
    for (const member of members) {
      const flags = [
        member.isStatic ? 'static' : '',
        member.deprecated !== null ? `deprecated: ${member.deprecated}` : '',
        member.visibleForTesting ? 'visible for testing' : '',
      ].filter((f) => f !== '');
      lines.push('', `### ${member.name}${flags.length > 0 ? ` (${flags.join(', ')})` : ''}`);
      lines.push('', '```dart', member.signature, '```');
      if (member.doc !== '') {
        lines.push('', member.doc);
      }
    }
  }
  return lines.join('\n');
}

export function renderSection(kb: KnowledgeBase, doc: DocEntry, section: DocSection): string {
  return [
    `# ${section.path.join(' › ')}`,
    '',
    `net_kit version: ${kb.version}`,
    `Source: ${doc.source}`,
    `Resource: ${docUri(section.id)}`,
    '',
    section.text,
  ].join('\n');
}

export function renderDoc(kb: KnowledgeBase, doc: DocEntry): string {
  const out = [`# ${doc.title}`, '', `net_kit version: ${kb.version}`, `Source: ${doc.source}`, ''];
  for (const section of doc.sections) {
    if (section.level > 0) {
      out.push(`${'#'.repeat(Math.min(section.level + 1, 6))} ${section.heading}`, '');
    }
    out.push(section.text, '');
  }
  return out.join('\n');
}

export function renderApiIndex(kb: KnowledgeBase): string {
  return JSON.stringify(
    {
      netKitVersion: kb.version,
      entrypoints: kb.artifact.entrypoints,
      symbols: kb.symbols.map((s) => ({
        name: s.name,
        kind: s.kind,
        entrypoints: s.entrypoints,
        deprecated: s.deprecated,
        resource: apiUri(s.name),
      })),
    },
    null,
    2,
  );
}

export function renderDocsIndex(kb: KnowledgeBase): string {
  return JSON.stringify(
    {
      netKitVersion: kb.version,
      documents: kb.docs.map((d) => ({
        id: d.id,
        title: d.title,
        category: d.category,
        source: d.source,
        resource: docUri(d.id),
        sections: d.sections.map((s) => ({ id: s.id, heading: s.heading, resource: docUri(s.id) })),
      })),
    },
    null,
    2,
  );
}
