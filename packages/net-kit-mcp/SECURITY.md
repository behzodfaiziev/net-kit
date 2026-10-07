# Security

This document describes the security model of the net_kit MCP server.

## Summary

| Property         | Guarantee                                                                                          |
| ---------------- | -------------------------------------------------------------------------------------------------- |
| Writes           | None. No tool or resource can create, modify, rename, or delete a file.                            |
| Execution        | None. No shell, subprocess, package manager, formatter, analyzer, or project code is run.          |
| Filesystem scope | Only authorized roots, after canonicalization and symlink resolution.                              |
| Secrets          | Likely secret files are refused; excluded directories are never entered; code excerpts are masked. |
| Network          | No outbound connections. No telemetry.                                                             |
| Persistence      | None. Project content lives in memory for one request.                                             |

## Root authorization

A project path can be read only if it lies inside an **authorized root**. Roots come from exactly one source per server process:

1. **Startup roots**: `--root <dir>` on the command line. When present, they are the only roots and client roots are ignored.
2. **Client roots**: the MCP client's roots. The server requests them on each workspace tool call (on the 2026-07-28 protocol through an `input_required` result, on earlier protocol versions through `roots/list`). Only `file://` URIs are accepted.

Nothing else can authorize a path: not the process working directory, environment variables, parent or sibling directories, the home directory, or anything found in project files. Without an authorized root, workspace tools return `no_authorized_root`; knowledge tools keep working.

Every root is canonicalized (`realpath`) and must be an existing directory. The filesystem root and the home directory itself are refused as too broad; project directories inside them are fine.

## Filesystem confinement

All project reads go through one resolver:

1. Reject empty input, input longer than 1024 characters, NUL bytes, and URIs.
2. Resolve the path against the root. Reject it if it leaves the root lexically (`..`, absolute paths elsewhere).
3. Canonicalize it with `realpath`, which resolves every symbolic link. Reject it if the result is outside the root.
4. Apply the read policy to the canonical root-relative path.

Percent-encoding is not decoded, so `%2e%2e` is a literal name and cannot become `..`. On case-insensitive filesystems the canonical name is used for policy checks, so `.ENV` is treated as `.env`.

Files are opened read-only with `O_NOFOLLOW`, checked to be regular files, and refused if they have more than one hard link (a hard link can expose a file from outside the root under a harmless name).

### Symbolic links

- An explicit path may traverse symbolic links only if the canonical target stays inside the root.
- File discovery never follows symbolic links.
- A symbolic link that points outside the root is reported as `path_escape`.

### Multiple roots

Roots are independent. A request selects one root by id or name; with several roots and no selection, the request is refused as ambiguous. Paths are resolved only against the selected root, so one authorized root cannot be reached through another.

## Sensitive files and excluded directories

Refused even when requested explicitly:

- `.env`, `.env.*`, `.netrc`, `.npmrc`, `.pypirc`, `.git-credentials`
- `*.pem`, `*.key`, `*.p8`, `*.p12`, `*.pfx`, `*.jks`, `*.keystore`, `*.mobileprovision`
- `id_rsa`, `id_dsa`, `id_ecdsa`, `id_ed25519` (and `.pub`)
- `credentials*`, `secret*`, `service-account*.json`, `google-services.json`, `GoogleService-Info.plist`, `key.properties`, `local.properties`

Never entered: `.git`, `.hg`, `.svn`, `.dart_tool`, `.pub-cache`, `.fvm`, `.idea`, `.gradle`, `.symlinks`, `.ssh`, `.aws`, `.gnupg`, `.docker`, `.kube`, `build`, `node_modules`, `Pods`, `coverage`, `ephemeral`. Discovery also skips other hidden directories.

Only text files relevant to analysis are read: `.dart`, `.yaml`, `.yml`, `.json`, `.md`, and `pubspec.lock` for dependency versions. Binary content is refused.

## Limits

Per request: maximum file size, number of files, total bytes, directory entries visited, directory depth, and findings returned. Results report when a limit was reached. Limits are configurable at startup.

## No execution, no writes

The server (the stdio entrypoint and every module it loads) contains no code path that writes to the filesystem, spawns a process, opens a network connection, or evaluates project code; a source-level test enforces this. The only writer in the source repository is the build-time `generate-knowledge` script, which regenerates `generated/netkit-knowledge.json`; the server never loads it and it is not part of the published package. Dart is analyzed by a lexer and a structural matcher written for this server. Suggestions are returned as text labeled `SUGGESTED — NOT APPLIED`.

## Prompt-injection boundary

Project files are **data**. Their contents are tokenized and matched against net_kit patterns; they are never interpreted as instructions. Text in a project, such as a comment asking to read `~/.ssh/id_rsa`, cannot:

- add, change, or select a root,
- widen the read policy or limits,
- disable redaction,
- trigger execution, or
- change server configuration.

Authorization comes only from the startup arguments and the MCP client's roots. Tool results mark source excerpts as untrusted (`sourceExcerptsAreUntrusted: true`) so clients can treat them accordingly.

## Output privacy

- Findings and errors use paths relative to the root; absolute paths are never returned, including in error messages for absolute input.
- Roots are identified by id and name only.
- Code excerpts have likely secrets masked: values of credential-like keys and headers, bearer tokens, JWT-shaped strings, well-known key formats, and signature or token query parameters.
- Configuration reports show only non-sensitive `NetKitManager` arguments; others appear as `"(set)"`.
- Unexpected errors are reported as `internal_error` without stack traces.

## Logging and telemetry

Logs go to stderr only (stdout carries MCP messages). They contain event names, tool names, durations, and error codes, never file contents, tool arguments, tokens, or absolute workspace paths. There is no telemetry.

## Knowledge vs. workspace capabilities

Handlers are registered in two groups:

- **knowledge**: tools, resources, and prompts answered from the bundled net_kit knowledge. No filesystem access at request time.
- **workspace**: project analysis of authorized roots.

`--no-workspace` (or omitting the workspace configuration when embedding the server) removes every workspace tool. A future remote deployment would expose only the knowledge group; local file access is not designed to be reachable remotely.

## Known limitations

- Between canonicalizing a path and opening it, a local process with write access to the project could swap a path component for a symbolic link. The final component is opened with `O_NOFOLLOW`; intermediate components are not re-checked. This requires an attacker who can already write to the authorized project.
- Static analysis is heuristic. Findings are hints with a confidence level, not proofs.

## Reporting a vulnerability

Please open a private security advisory on the repository, or contact the maintainer listed in the repository, rather than filing a public issue.
