# The Claude Code module

`modules/programs/claude-code/claude-code.nix` defines the
`flake.programs.claude-code` declaration. The `jake.neau` user requests this
program on cedar. The module installs Claude Code configuration, language
servers, Model Context Protocol servers, hooks, commands, skills, and the
writing linter.

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
