# Edit-briefing ledger

Before **every** `Edit` or `Write` tool call, first append a one-line rationale to
the session edit-briefing ledger with a Bash command. A global `PreToolUse` hook
(`edit-briefing`) reads that line and shows it as the WHY above the user's
accept/deny prompt for the edit. This surfaces the what/where/why you already state
before each edit (CLAUDE.md §6) at the exact moment the user judges it.

## How

Immediately before each edit, run exactly one append — substitute the real
absolute path and a concise one-line reason (no tabs, no newlines):

    mkdir -p "${CLAUDE_CODE_TMPDIR:-${TMPDIR:-/tmp}}/claude-edit-briefings" && \
    printf '%s\t%s\t%s\n' "$(date +%s)" "/abs/path/to/file" "why this edit is needed" \
      >> "${CLAUDE_CODE_TMPDIR:-${TMPDIR:-/tmp}}/claude-edit-briefings/ledger.tsv"

- One append per edit, in edit order — the hook matches lines first-in-first-out
  per file path.
- Use the **same absolute path** you pass to the edit tool.
- Keep the reason to a single line: the *why*, never a restatement of the diff.
- This is deliberately a Bash append to a sandbox-writable temp path: it is
  prompt-free and fires no write-gate or hook. **Never** write the ledger with the
  Edit or Write tools.
- Best-effort: if you skip it, the briefing still shows deterministic evidence,
  only without your WHY.
