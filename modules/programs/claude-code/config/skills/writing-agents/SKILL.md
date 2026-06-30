---
name: writing-agents
description: How to author a Claude Code subagent in this repo — a markdown file under config/agents/ with name/description/tools/model frontmatter and a system-prompt body. Covers the frontmatter fields, how the description drives automatic delegation, least-privilege tool restriction, and single-responsibility prompt design. Use when creating, editing, or removing a subagent (agent) for Claude, globally or "for me".
---

# Writing subagents

A subagent is a focused assistant with its own system prompt, tool set, and
(optionally) model, that Claude can delegate a task to. Author one as a markdown
file; see [[skill:claude-code-config]] for the edit → `git add` → rebuild flow.

## Where it goes

`config/agents/<name>.md` → `~/.claude/agents/<name>.md`. The file is markdown:
YAML frontmatter, then the system prompt as the body.

## Frontmatter

```markdown
---
name: code-reviewer
description: Reviews a diff for correctness and security. Use proactively after writing code.
tools: Read, Grep, Bash
model: sonnet
---
```

- `name` (required) — kebab-case, unique within scope, equals the filename.
- `description` (required) — **this is what makes Claude delegate to the agent.**
  Write it as what the agent does plus a concrete trigger; "use proactively" /
  "use when…" phrasing increases automatic delegation.
- `tools` (optional) — comma-separated allowlist. **Omitting it inherits ALL
  tools; restrict it** to the minimum the agent needs (least privilege + focus).
- `model` (optional) — `sonnet` / `opus` / `haiku` / `fable` / `inherit`.

The full, current field list lives in the docs (below) — link there rather than
trusting a snapshot, since fields change.

## Best practices

- **One responsibility per agent.** A narrow agent outperforms a generalist and
  delegates more reliably.
- **Make the description do the routing** — it is read to decide *when* to use
  the agent. Be specific about the triggering situation.
- **Restrict `tools`** to what the job needs; a reviewer rarely needs `Write`.
- **Write a detailed system prompt** with the steps to follow and 1–2 examples of
  good output; don't assume the agent shares the main session's context.
- Organize many agents into subdirectories — folders don't change the agent name.

## Worked examples

This config already ships a family of agents — read them as templates for the shape
above. [[agent:code-writer]] is the orchestrator that turns a task into proven code; it
leans on the code-verification family — [[agent:code-reviewer]] (the capstone),
[[agent:test-writer]], [[agent:test-verifier]], [[agent:codebase-investigator]], [[agent:comment-writer]],
and [[agent:comment-style-enforcer]] — plus [[agent:plan-verifier]] to vet its spec and the
standalone [[agent:web-researcher]]. A documentation family mirrors it — [[agent:doc-writer]]
(authors docs), [[agent:doc-reader]] (read-only retrieval), and [[agent:doc-reviewer]] (the
coverage/accuracy capstone), all following [[skill:diataxis]]. Each is a
single-responsibility prompt with a least-privilege tool set.

## Reference

Official docs (authoritative field list and behavior):
https://code.claude.com/docs/en/sub-agents

## Related skills

- [[skill:claude-code-config]] — the declarative edit/ship workflow
- [[skill:writing-commands]] — slash commands often pair with agents
- [[skill:writing-skills]] — when a reusable *procedure* fits a skill better
- [[skill:machine-layout]] — the Nix machine these ship from
