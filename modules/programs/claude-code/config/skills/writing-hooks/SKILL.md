---
name: writing-hooks
description: How to author a Claude Code hook in this repo — an executable script under config/hooks/ that runs on lifecycle events (PreToolUse, PostToolUse, etc.). Both the script and its registration are declarative: ship the script under config/hooks/ and register it in the settingsPolicy.hooks attrset in claude-code.nix, which is deep-merged into settings.json at activation. Covers events, JSON stdin, exit codes, and security. Use when adding automation that should run automatically before/after a tool call, prompt, or session event.
---

# Writing hooks

A hook is a script Claude Code runs automatically on a lifecycle event. Authoring
a working hook in this repo is **two steps**, both declarative and shared across
machines through the flake.

## The two steps (read first)

1. **Ship the script.** `config/hooks/<name>` → `~/.claude/hooks/<name>`, written
   verbatim and marked executable. See [[skill:claude-code-config]] for the edit →
   `git add` → rebuild flow.
2. **Register it.** Registration activates the shipped script. Add an entry to
   the `settingsPolicy.hooks` attrset in `claude-code.nix` under
   `<Event>`. Give it a `command` pointing at `~/.claude/hooks/<name>`. Add a
   matcher when the event supports useful registration-time filtering.
   Activation deep-merges `settingsPolicy` into the runtime `settings.json`.

**Array gotcha:** the merge is jq's `*`, which replaces arrays wholesale rather
than appending. Each event's value is an array, so `settingsPolicy.hooks.<Event>`
must list the **complete** set of registrations for that event — any one omitted
is dropped from the live file.

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
- **Matcher** selects which tools or event variants fire the hook. Examples
  include `Bash`, `Edit|Write`, and `mcp__.*`.
- **Omit `matcher`** when the hook must receive every variant of an event. An
  absent `SessionStart` matcher covers startup, resume, clear, and compact.
  A hook may also omit it when the script must self-filter from payload fields,
  such as `agent_type` on `SubagentStop`.

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

- [[skill:claude-code-config]] — shipping the script and registration declaratively
- [[skill:writing-commands]] — for on-demand automation instead of event-driven
- [[skill:machine-layout]] — the Nix machine these ship from
