---
name: writing-hooks
description: How to author a Claude Code hook in this repo — an executable script under config/hooks/ that runs on lifecycle events (PreToolUse, PostToolUse, etc.). IMPORTANT — the Nix module ships the script but does NOT register it; you must register it in the runtime settings.json for it to fire. Covers events, JSON stdin, exit codes, and security. Use when adding automation that should run automatically before/after a tool call, prompt, or session event.
---

# Writing hooks

A hook is a script Claude Code runs automatically on a lifecycle event. Authoring
a working hook in this repo is **two steps** — and the second is easy to forget.

## The two-step gotcha (read first)

1. **Ship the script (declarative).** `config/hooks/<name>` →
   `~/.claude/hooks/<name>`, written verbatim and marked executable. See
   [[skill:claude-code-config]] for the edit → `git add` → rebuild flow.
2. **Register it (runtime).** The Nix module **does not** wire the script into
   `settings.json`, so on its own **the hook never fires**. You must register it
   in the runtime-mutable `~/.claude/settings.json` under `hooks.<Event>` with a
   matcher and a `command` pointing at `~/.claude/hooks/<name>`. Use the built-in
   `update-config` skill to edit settings.json.

Caveat: that registration lives in unmanaged `settings.json`, so it is
**per-machine** and not shared by the flake. Only the script is shared.

## Events

`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`, `SubagentStop`,
`SessionStart`, `SessionEnd`, `Notification`, `PreCompact`, and more — see the
docs for the current full list.

## Script contract

- **Input:** a JSON object on **stdin** (`hook_event_name`, `cwd`, and for tool
  events `tool_name` / `tool_input` / `tool_result`, …).
- **Output / control:**
  - exit `0` — success; JSON on stdout can add context or a decision.
  - exit `2` — **block** the action; stderr is shown to Claude/user.
  - other — non-blocking error; stderr shown as a notice.
- **Matcher** (in the settings.json registration) selects which tools/events fire
  the hook (`Bash`, `Edit|Write`, regex like `mcp__.*`).

## Best practices

- **Validate and parse stdin** before acting; never assume well-formed input.
- **Quote inputs / use exec-form args**; never interpolate untrusted paths into a
  shell string.
- Use **absolute paths**; set a sensible `timeout`.
- Remember **hooks run with the user's full credentials** — keep them simple and
  auditable.

## Reference

Official docs (events, JSON schema, registration):
https://code.claude.com/docs/en/hooks

## Related skills

- [[skill:claude-code-config]] — shipping the script declaratively
- the built-in `update-config` skill — registering the hook in settings.json
- [[skill:writing-commands]] — for on-demand automation instead of event-driven
- [[skill:machine-layout]] — the Nix machine these ship from
