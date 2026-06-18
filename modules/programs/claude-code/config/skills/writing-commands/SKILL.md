---
name: writing-commands
description: How to author a Claude Code slash command in this repo — a markdown file under config/commands/ with description/argument-hint/allowed-tools/model frontmatter and a prompt body that can use $ARGUMENTS / $1, !`bash`, and @file references. Use when creating, editing, or removing a custom slash command for Claude.
---

# Writing slash commands

A slash command is a reusable prompt invoked as `/<name>`. Author one as a
markdown file; see [[claude-code-config]] for the edit → `git add` → rebuild flow.

## Where it goes

`config/commands/<name>.md` → `~/.claude/commands/<name>.md`, invoked as
`/<name>`. Subdirectories namespace the command but the file body is the prompt.

## Frontmatter

```markdown
---
description: Open a PR for the current branch
argument-hint: [base-branch]
allowed-tools: Bash(git*), Bash(gh*)
model: sonnet
---
```

- `description` — shown in the `/` menu and used for discovery; lead with the
  primary use.
- `argument-hint` — autocomplete hint, e.g. `[issue-number]`.
- `allowed-tools` — pre-approve specific tools so the command runs without
  permission prompts.
- `model`, `disable-model-invocation` (set `true` for side-effecting workflows
  Claude shouldn't auto-run, e.g. deploy/commit).

## Body features

- `$ARGUMENTS` — everything typed after the command; `$1`, `$2` — positional args.
- `` !`command` `` — runs bash **before** the prompt is sent; its output is
  spliced into the prompt (great for `!`git diff`` etc.).
- `@path/to/file` — injects that file's contents into the prompt.

## Best practices

- Put the primary use case first in `description`.
- Use `allowed-tools` to avoid repeated permission prompts for the command's
  expected tools.
- Set `disable-model-invocation: true` for commands with side effects.
- Keep one command focused; compose, don't build a mega-command.

## Reference

Official docs (authoritative field list and substitutions):
https://code.claude.com/docs/en/slash-commands

## Related skills

- [[claude-code-config]] — the declarative edit/ship workflow
- [[writing-agents]] — delegate heavier work to a subagent (e.g. [[code-reviewer]])
- [[writing-hooks]] — run automation on events instead of on demand
