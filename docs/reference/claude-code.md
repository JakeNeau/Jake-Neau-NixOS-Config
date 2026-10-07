# The Claude Code module

`modules/programs/claude-code/claude-code.nix` defines the
`flake.programs.claude-code` declaration. The `jake.neau` user requests this
program on cedar. The module installs Claude Code configuration, language
servers, Model Context Protocol servers, hooks, commands, skills, and the
writing linter. It also installs the Open Claude in Chrome browser extension.

The subsystem rationale is in
[The declarative Claude Code subsystem](../explanation/claude-code-config.md).
The per-user routing is in [Coding agents](../explanation/coding-agents.md).

## Managed configuration

The source tree is `modules/programs/claude-code/config/`.

| Source | Managed destination |
|---|---|
| `agents/*.md` | `~/.claude/agents/*.md` |
| `commands/*.md` | `~/.claude/commands/*.md` |
| `rules/*.md` | `~/.claude/rules/*.md` |
| `hooks/*` | Executable files under `~/.claude/hooks/` |
| `skills/*/SKILL.md` | `~/.claude/skills/*/SKILL.md` |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` |

Home Manager materializes this content from Nix. `settings.json` remains
mutable because Claude Code rewrites runtime preferences. Home activation
merges the declared policy into that file with `jq`.

## Hook registration

`settingsPolicy.hooks` contains the complete registration array for each event.
The activation merge replaces arrays rather than appending them.

A matcher filters a hook at registration time. An absent matcher receives every
variant of that event. The `SessionStart` registration omits its matcher so it
runs for startup, resume, clear, and compact. The `SubagentStop` registration
also omits it because the hook self-filters from `agent_type` in the payload.

## Open Claude in Chrome

`modules/programs/claude-code/open-claude-in-chrome.nix` adds to the
`flake.programs.claude-code` declaration's `config`. Only homes that request
Claude Code evaluate it. The design rationale is in [Chromium
extensions](../explanation/chromium-extensions.md#open-claude-in-chrome).

| Item | Value |
|---|---|
| Source | Flake input `open-claude-in-chrome` (`github:noemica-io/open-claude-in-chrome`, `flake = false`), which tracks `main` |
| Extension ID | `ghpielhenbpoohlpehajamjhhoajejph` |
| Signing key | `modules/programs/claude-code/open-claude-in-chrome.pem` |
| Extension version | `<upstream manifest version>.<input lastModified / 86400>` |
| Native messaging host | `com.anthropic.open_claude_in_chrome` |
| MCP server | `open-claude-in-chrome` |

The module adds three entries:

- `programs.chromium.extensions` receives the CRX. The build rewrites the
  manifest version, then packs upstream's `extension/` directory with `crx3`.
- `programs.chromium.nativeMessagingHosts` receives the host manifest
  `etc/chromium/native-messaging-hosts/com.anthropic.open_claude_in_chrome.json`.
  The manifest has type `stdio` and allows only
  `chrome-extension://ghpielhenbpoohlpehajamjhhoajejph/`. Its wrapper script
  runs `native-host.js` with the Nix-store `node`.
- `programs.mcp.servers.open-claude-in-chrome` runs `mcp-server.js` with the
  same `node`. `enableMcpIntegration` passes the server to Claude Code.

`buildNpmPackage` packages upstream's `host/` directory with `importNpmLock`.
An input update therefore needs no `npmDepsHash`.

home-manager writes the browser files only where a declaration enables
`programs.chromium`. The `ungoogled-chromium` declaration does so on every
host. On
macOS the files go under `~/Library/Application Support/Chromium/`:

| Path | Content |
|---|---|
| `External Extensions/ghpielhenbpoohlpehajamjhhoajejph.json` | The CRX store path and its version |
| `NativeMessagingHosts/` | The native messaging host manifest |

On Linux the same paths go under `~/.config/chromium/`.

Two checks stop a broken extension:

- Evaluation fails when the upstream manifest version does not have one to
  three numeric parts.
- The CRX build fails when the packed ID differs from
  `ghpielhenbpoohlpehajamjhhoajejph`.

## `claude-writing-lint`

`modules/programs/claude-code/writing/writing_lint.py` implements the linter.
It accepts Markdown and plain-text paths. With no paths, it reads standard
input.

```sh
claude-writing-lint [--json] [<file> ...]
```

| Exit status | Meaning |
|---|---|
| `0` | No diagnostics. |
| `1` | One or more deterministic or heuristic diagnostics. |
| `2` | Invalid arguments, an unsupported file type, or an unreadable file. |

Normal output contains the source, line, rule, message, and suggestion.
Heuristic diagnostics include a `[candidate]` marker. `--json` returns an array
whose entries contain `source`, `line`, `rule`, `message`, `suggestion`, and
`heuristic`.

## `/writing-review`

The managed `/writing-review [scope]` command reviews substance before form.
With no scope, it reviews prose changed in `git diff HEAD`. A path, directory,
or commit range replaces that default.

The command removes unsupported material, applies the required writing
structure, runs `claude-writing-lint`, and reports retained heuristic
exceptions. It changes no code logic.
