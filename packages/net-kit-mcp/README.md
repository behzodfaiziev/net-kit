# flutter-net-kit-mcp

A read-only [Model Context Protocol](https://modelcontextprotocol.io) server for [`net_kit`](https://pub.dev/packages/net_kit), the Dart/Flutter networking package. It gives MCP-compatible clients such as Claude Code, Claude Desktop, and Cursor:

- current, version-specific net_kit API knowledge;
- architecture guidance: which client, body type, and auth policy to use;
- auth, token refresh, and session guidance;
- upload and streaming guidance;
- 5.x → 6.0 migration help;
- optional read-only inspection of Flutter/Dart projects you authorize.

It never modifies your code.

## Why use it?

net_kit makes deliberate security and memory decisions that are easy to get subtly wrong. This server helps an assistant get them right, and spot where a project gets them wrong:

- **The right client.** `NetKitManager` for your own API, `RawHttpClient` for absolute URLs such as signed storage uploads.
- **Auth policy.** When to use `AuthPolicy.inherit`, `none`, or `required`, and what each guarantees.
- **Sessions.** Only a refresh-endpoint 401 ends a session; offline, timeouts, and server errors do not. It finds sign-out logic that breaks this rule.
- **Uploads.** Signed GCS/S3 uploads without leaking the access token, and large uploads that stream from disk and survive a token refresh.
- **Streaming and cancellation.** Buffered downloads that should stream, single-shot bodies that cannot be retried, uploads that cannot be cancelled.
- **Migration.** net_kit 5.x usages and a concrete 5.x → 6.0 plan.
- **Configuration.** Cross-origin settings, body logging, plain-HTTP base URLs, direct Dio clients that bypass net_kit.

## Quick start

Requires Node.js 20 or later. The server speaks MCP over stdio.

```bash
npx -y flutter-net-kit-mcp
```

**Claude Code**

```bash
claude mcp add net-kit -- npx -y flutter-net-kit-mcp
```

**Other MCP clients.** Clients configured with an `mcpServers` object (for example Cursor or Claude Desktop) use this entry:

```json
{
  "mcpServers": {
    "net-kit": {
      "command": "npx",
      "args": ["-y", "flutter-net-kit-mcp"]
    }
  }
}
```

Where this JSON goes differs per client; see your client's MCP documentation. Development pre-releases are published under the npm `next` tag; `flutter-net-kit-mcp@next` always selects the newest one.

## Workspace authorization

Knowledge tools need no permission. Project analysis needs an **authorized root**, given in one of two ways:

1. **Client roots.** If your client shares its workspace folders as MCP roots, the server asks for them on each analysis call.
2. **Explicit roots.** Pass one or more directories at startup:

```bash
npx -y flutter-net-kit-mcp --root /path/to/flutter-app
```

```json
{
  "mcpServers": {
    "net-kit": {
      "command": "npx",
      "args": ["-y", "flutter-net-kit-mcp", "--root", "/path/to/flutter-app"]
    }
  }
}
```

Repeat `--root` to authorize several projects; each stays a separate boundary. When `--root` is given, client roots are ignored. Without any root, analysis tools decline and knowledge tools keep working.

## Knowledge-only mode

For API and design questions without any project access:

```bash
npx -y flutter-net-kit-mcp --no-workspace
```

This registers only the knowledge tools, resources, and prompts: the smallest capability surface.

## Example questions

Ask your MCP client in plain language; it picks the tools:

- "Which net_kit API should I use for a signed GCS or S3 upload?"
- "Review this project's token refresh flow."
- "Can this code sign a user out when the device is offline?"
- "Find net_kit 5.x usages and give me a migration plan."
- "Is this large upload buffering the whole file in memory?"
- "Should this request use `AuthPolicy.none` or `AuthPolicy.required`?"
- "Review my `NetKitManager` configuration."

## Tools

| Knowledge                  |                                                                                 |
| -------------------------- | ------------------------------------------------------------------------------- |
| `search_netkit`            | Search the public API and documentation                                         |
| `get_netkit_api`           | Exact declaration of a public symbol: signature, members, docs                  |
| `explain_netkit_pattern`   | An established pattern with rationale, security notes, and example              |
| `recommend_netkit_pattern` | Pick client, call, auth policy, and body type from requirements, with reasoning |

| Workspace                       |                                                                         |
| ------------------------------- | ----------------------------------------------------------------------- |
| `list_workspace_roots`          | Authorized roots (ids and names, never paths)                           |
| `inspect_netkit_usage`          | All rules over a project                                                |
| `review_auth_flow`              | Auth policies, token attachment, origins, sign-out handling             |
| `review_refresh_flow`           | Refresh setup and sign-out logic against the session rule               |
| `review_upload_flow`            | API uploads vs. signed-URL uploads: memory, replay, cancellation, leaks |
| `review_streaming_usage`        | Buffered downloads and non-replayable bodies                            |
| `check_v5_to_v6_migration`      | Project-specific migration checklist                                    |
| `validate_netkit_configuration` | Every `NetKitManager` setup and its risky settings                      |

Workspace tools accept `root` (when several are authorized) and `paths` (default `lib/`).

**Prompts:** `review-netkit-network-layer`, `review-netkit-auth`, `migrate-netkit-v5-to-v6`, `design-netkit-upload`, `design-netkit-streaming`.

## Resources

| URI                                              | Content                                                                  |
| ------------------------------------------------ | ------------------------------------------------------------------------ |
| `netkit://overview`                              | Architecture summary and resource map                                    |
| `netkit://version`                               | net_kit version the knowledge describes                                  |
| `netkit://rules`                                 | The analyzer's rules                                                     |
| `netkit://api/index`, `netkit://api/{symbol}`    | Public API, for example `netkit://api/AuthPolicy`                        |
| `netkit://docs/index`, `netkit://docs/{section}` | README, token management, migration, examples, changelog, or one section |

## Security and privacy

- **Read-only.** No tool writes, renames, or deletes files. Suggestions are returned as text labeled `SUGGESTED — NOT APPLIED`.
- **No execution.** No shell, no subprocesses, no project code, no package manager.
- **Authorized roots only.** Paths are canonicalized; `..`, outside absolute paths, and symlinks that leave a root are refused.
- **Secrets skipped.** `.env*`, keys, keystores, credentials, `google-services.json` and similar files are never read; `.git/`, `build/`, `.dart_tool/` and similar directories are never entered.
- **Bounded.** File size, file count, bytes, and findings are capped per request.
- **Local and ephemeral.** No outbound network access and no telemetry. Project source is read for one request and never persisted. Results use paths relative to the root, with likely secrets in excerpts masked.
- **Project text is data.** Comments or strings in your code cannot change what the server reads.

These are the server's own guarantees, not an OS-level sandbox. See [SECURITY.md](SECURITY.md) for the full model and its known limitations.

## How analysis works

The workspace analyzer is deliberately net_kit-specific. It is **not** a general Dart analyzer, a replacement for `dart analyze`, or a type and data-flow engine. It reads source with a lexical and structural matcher and applies 16 rules (`NK001`–`NK016`, listed at `netkit://rules`), for example:

| Rule  | Finds                                                                              |
| ----- | ---------------------------------------------------------------------------------- |
| NK001 | A signed storage URL sent through the authenticated `NetKitManager`                |
| NK004 | A file read fully into memory (`readAsBytes`) before upload                        |
| NK007 | Sign-out triggered by offline, timeout, or any 401 instead of session invalidation |
| NK009 | An `Authorization` header attached to a raw request                                |

Every finding has a severity, a **confidence** (`high`, `medium`, `low`), a root-relative location, the documentation it is based on, and often a suggested change. Medium and low confidence findings are review hints, not proofs.

Analysis runs locally and returns bounded, structured findings rather than source files, so an MCP client does not need to place a project's raw source in the model's context to review its net_kit usage. Knowledge searches likewise return ranked excerpts with links instead of whole documents. How much of any result reaches the model depends on your client.

## Limitations

- The analysis is heuristic: without type resolution it can miss indirect code and cannot prove behavior. Confidence levels reflect this.
- Only `lib/` is inspected by default; pass `paths` for more.
- Knowledge covers net_kit 6.0.0-dev.1 and the 5.x → 6.0 migration. Newer net_kit APIs are known only after a matching release of this package.

## Compatibility

|                     |                                                                    |
| ------------------- | ------------------------------------------------------------------ |
| Package             | `flutter-net-kit-mcp` 0.1.0-dev.1 (development pre-release)        |
| Node.js             | 20 or later                                                        |
| net_kit knowledge   | 6.0.0-dev.1 (see `netkit://version`)                               |
| Migration knowledge | 5.x → 6.0                                                          |
| MCP                 | 2025-era (`initialize`) and 2026-07-28 (`server/discover`) clients |

### Options

| Option                  | Default | Meaning                                          |
| ----------------------- | ------- | ------------------------------------------------ |
| `--root <dir>`          | none    | Authorize a project directory (repeatable)       |
| `--no-workspace`        | off     | Knowledge only                                   |
| `--log-level <level>`   | `error` | `silent`, `error`, `info`, `debug` (stderr only) |
| `--max-file-bytes <n>`  | 524288  | Largest file read                                |
| `--max-files <n>`       | 300     | Files read per request                           |
| `--max-total-bytes <n>` | 6291456 | Bytes read per request                           |
| `--max-diagnostics <n>` | 200     | Findings returned per request                    |

## Development

From a checkout of the [net_kit repository](https://github.com/behzodfaiziev/net-kit):

```bash
cd packages/net-kit-mcp
npm ci
npm run build
npm test
npm run check:knowledge   # fails if the bundled knowledge is stale
npm run generate          # rebuild knowledge from ../net-kit
```

Also available: `npm run typecheck`, `npm run lint`, `npm run format:check`, and `npm run dev` to build and start the server. The knowledge generator needs the adjacent `../net-kit` package; the published server does not.

## Architecture and security

- [docs/architecture.md](docs/architecture.md): server core, knowledge generation, analyzer, workspace layer, transport.
- [SECURITY.md](SECURITY.md): root authorization, confinement, sensitive files, prompt-injection boundary, limitations.

## License

MIT
