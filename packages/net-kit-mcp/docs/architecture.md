# Architecture

```
            MCP client
                │  stdio (2025-era initialize or 2026-07-28 server/discover)
                ▼
   transports: src/bin/stdio.ts ── serveStdio(factory)
                │
                ▼
   server core: src/server/createServer.ts ── createNetKitMcpServer(options)
        │                          │
        │ knowledge group          │ workspace group (optional)
        ▼                          ▼
   tools/knowledgeTools.ts     tools/workspaceTools.ts
   resources/  prompts/        server/roots.ts (root acquisition)
        │                          │
        ▼                          ▼
   knowledge/                  workspace/ (confinement, policy, limits, session)
   patterns/                   analyzer/ (model, rules, engine)
        │                          │
        └──────────── dart/lexer.ts ┘
```

## Server core

`createNetKitMcpServer(options)` builds an `McpServer` from the official TypeScript SDK (v2, `@modelcontextprotocol/server`). It does not know about transports. The stdio entrypoint passes it as the server factory to `serveStdio`, which selects the protocol era from the client's opening message and creates one instance per connection. A future Streamable HTTP host would call the same factory.

Options:

- `knowledge`: a `KnowledgeBase` or a loader; loaded lazily on first use and shared.
- `workspace`: `{ policy, limits }`. When absent, no workspace tool is registered.
- `logger`: stderr logger (silent by default when embedded).

## Knowledge layer

`knowledge/` serves answers from `generated/netkit-knowledge.json`, which is bundled in the package:

- **API metadata** (source-derived). The generator reads net_kit's library files with the shared lexer, follows the export graph from `lib/net_kit.dart` and `lib/net_kit_dio.dart` (honoring `show`/`hide` and `part` files), and records every public declaration: kind, signature, Dartdoc, deprecation, entrypoints, source location, and public members. Private declarations are dropped. Source is authoritative for what exists.
- **Documentation** (curated). README, token management, migration guide, examples, and changelog of the net_kit package, split into sections at headings (HTML comments removed). Documentation is authoritative for how to use the API.
- **Version**: read from net_kit's `pubspec.yaml`, stored once in the artifact, and attached to every knowledge answer.

### Build time vs. runtime

The generator (`bin/generate-knowledge.ts`, `knowledge/generate.ts`, `knowledge/dartApi.ts`, `knowledge/markdown.ts`) runs only in a repository checkout, where it reads the adjacent `../net-kit` package (`npm run generate`). It is excluded from the published package. The runtime loads only the bundled artifact and never needs a net_kit checkout. A test verifies that no runtime module imports the generator and that the package excludes exactly those files; another regenerates the artifact in memory and fails when the committed copy is stale (`npm run check:knowledge`).

Search is a local BM25 index over symbols and sections (identifiers are split on camelCase and snake_case). There are no embeddings, external services, or network calls.

`patterns/` holds the curated pattern catalog and the deterministic recommender. Each pattern names the symbols and resources it relies on; a test checks they exist in the generated knowledge.

## Semantic analyzer

`analyzer/` is specific to net_kit; it is not a general Dart linter.

1. **Model** (`model.ts`). The lexer tokenizes the file (comments, doc comments, raw/triple-quoted strings, and interpolation are handled, so code inside comments or strings is never matched). The model extracts call sites with positional and named arguments, imports, and the headers of enclosing blocks (`catch`, `if (...)`, method declarations, named-argument closures).
2. **Rules** (`rules/`). Sixteen rules, `NK001`–`NK016`, each reporting severity, confidence, a root-relative range, an explanation, a recommendation, citations, and an optional text suggestion. Rules key on net_kit-specific names and arguments (`uploadRawData`, `authPolicy:`, `onSessionInvalidated:`, `RawHttpRequest(headers:)`), which keeps them precise without type resolution.
3. **Engine** (`engine.ts`). Targeted discovery (default `lib/` plus `pubspec.yaml`/`pubspec.lock`), project facts (net_kit constraint and resolved version, literal API hosts, whether refresh is configured), rule execution, ordering, and diagnostic limits.

Parser choice: a full Dart parser would require either shipping the Dart SDK (and executing it) or a large grammar runtime. The lexer plus structural matching is small, has no dependencies, executes nothing, and is sufficient for net_kit-specific patterns. Its limit is the absence of type and data-flow analysis, which is why every finding carries a confidence level.

## Root-confined workspace layer

`workspace/` is the only code that touches project files:

- `roots.ts`: validates and canonicalizes roots, refuses too-broad roots, and selects one root per request.
- `clientRoots.ts`: converts client-provided `file://` roots, validating each independently.
- `pathGuard.ts`: the single resolver from caller input to a canonical path inside a root.
- `policy.ts`: excluded directories, sensitive file names, readable extensions.
- `session.ts`: per-request, read-only access with budgets; opens files with `O_NOFOLLOW`, refuses non-regular, multiply hard-linked, oversized, and binary files; discovery never follows symbolic links.

`server/roots.ts` acquires roots for a request: startup roots when configured, otherwise the client's roots (an `input_required` round trip on 2026-07-28; the SDK performs `roots/list` for 2025-era connections). Root state is request-scoped, so concurrent requests cannot affect each other's root.

## Transport layer

`bin/stdio.ts` parses options, authorizes startup roots, and calls `serveStdio`. stdout carries only MCP messages; diagnostics go to stderr. Nothing is scanned or loaded at startup. The process shuts down when stdin closes or on SIGINT/SIGTERM.

## Local vs. future remote

Handlers are registered in two groups: **knowledge** (no filesystem access at request time) and **workspace** (local project files). A remote deployment would register only the knowledge group. It would additionally need:

- Streamable HTTP transport (the SDK provides it; the server factory is already transport-independent),
- client authentication and authorization,
- rate limiting and request size limits,
- tenant separation for any per-session state,
- explicit selection of the net_kit knowledge version served.

Workspace analysis is designed for local operation only: it reads the local filesystem and must not be exposed remotely. A remote analysis feature would have to receive file contents from the client explicitly, under a separate design.

## Read-only by design

No module of the server writes files, spawns processes, or evaluates project code, and no tool accepts content to write. If mutation is ever considered, it would be a separate, explicitly opt-in capability with its own review; the current architecture does not anticipate it.
