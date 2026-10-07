import type { DocSection } from './types.js';

/** GitHub-style heading slug. */
export function slugify(heading: string): string {
  return heading
    .toLowerCase()
    .replace(/[*_`[\]()]/g, '')
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-');
}

/** Removes HTML comments, which hold notes that are not rendered documentation. */
export function stripHtmlComments(markdown: string): string {
  return markdown.replace(/<!--[\s\S]*?-->/g, '');
}

/**
 * Splits [markdown] into sections at `#`–`####` headings. Headings inside
 * fenced code blocks are ignored. Section ids are `<docId>.<slug>` and are
 * made unique within the document.
 */
export function splitSections(docId: string, title: string, markdown: string): DocSection[] {
  const lines = stripHtmlComments(markdown).split('\n');
  const sections: DocSection[] = [];
  const stack: { level: number; heading: string }[] = [];
  const used = new Map<string, number>();
  let current: { heading: string; level: number; path: string[]; body: string[] } = {
    heading: title,
    level: 0,
    path: [title],
    body: [],
  };
  let inFence = false;

  const flush = (): void => {
    const text = current.body.join('\n').trim();
    if (text.length === 0 && current.level === 0) {
      return;
    }
    const base = current.level === 0 ? 'intro' : slugify(current.heading) || 'section';
    const count = used.get(base) ?? 0;
    used.set(base, count + 1);
    const slug = count === 0 ? base : `${base}-${count}`;
    sections.push({
      id: `${docId}.${slug}`,
      docId,
      heading: current.heading,
      path: current.path,
      level: current.level,
      text,
    });
  };

  for (const line of lines) {
    if (/^\s*(```|~~~)/.test(line)) {
      inFence = !inFence;
    }
    const match = inFence ? null : /^(#{1,4})\s+(.+?)\s*#*\s*$/.exec(line);
    if (match) {
      flush();
      const level = match[1]?.length ?? 1;
      const heading = (match[2] ?? '').replace(/\*\*/g, '').trim();
      while (stack.length > 0 && (stack[stack.length - 1]?.level ?? 0) >= level) {
        stack.pop();
      }
      stack.push({ level, heading });
      current = { heading, level, path: [title, ...stack.map((s) => s.heading)], body: [] };
    } else {
      current.body.push(line);
    }
  }
  flush();
  return sections;
}
