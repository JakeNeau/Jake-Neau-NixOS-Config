# Edit briefings

A global hook that prints a compact four-part briefing above every Edit/Write
accept/deny prompt, so the user has the context to evaluate each edit.

## Spec

### The problem

At Claude Code's accept/deny prompt for a file edit, the user lacks the context
to judge the edit or build a mental model of the code. Per edit they want four
things: (1) **why** the edit is needed, (2) **what** the edit does in full,
(3) **why** it lives in that file location, (4) **how** it relates to the
surrounding and other files. In this setup non-trivial edits are made by
headless subagents (code-writer, test-writer, doc-writer, comment-writer,
spec-writer, …) whose reasoning never reaches the prompt — so the "why" exists
but is trapped inside the subagent.

### Mechanism constraints (fixed facts)

- Claude Code exposes **no field to render text inside the accept/deny dialog**,
  and the Edit/Write tools have **no rationale/description field**.
- A `PreToolUse` hook is the only lever that can print text near the prompt —
  via `systemMessage`, or by returning `permissionDecision: "ask"` with
  `permissionDecisionReason`. Which one renders most tightly above the prompt is
  verified empirically at build time.
- A hook **cannot call back into the live session model** (it is paused awaiting
  the tool). No separate/extra model call, no headless `claude -p`, no API key.
- `PreToolUse` hook stdin includes `agent_type` (present only for subagent
  calls), `tool_input.file_path`, `tool_input.old_string`,
  `tool_input.new_string`.

### The decision: a plumbing-only hook over a session ledger plus deterministic evidence

A global `PreToolUse` hook on Edit and Write prints a compact four-part briefing
(**WHY / WHAT / WHERE / RELATES**) immediately above each accept/deny prompt.
There is **no new model call**: the "why" is authored by the model already
making the edit (the running subagent) and written to a session ledger; the hook
is pure plumbing that looks it up and prints it alongside deterministic evidence
the hook computes itself.

The design splits into three components.

**1. Ledger convention (author side).** Before each Edit/Write, the acting agent
appends a one-line rationale to a session-scoped ledger, keyed by the exact edit
text (e.g. a hash of `new_string`, or `file_path` + hash). The append is done
via a **Bash append** (e.g. `echo … >> "$ledger"`) to a **sandbox-writable
temp/session path** — **not** via the Edit/Write tools. A Bash append fires
neither the main-session write-gate (`Write|Edit|NotebookEdit`) nor this
briefing hook (`Edit|Write`), and `autoAllowBashIfSandboxed` makes it prompt-free
as long as the ledger stays inside the bash sandbox — so there is no second
permission prompt and no hook recursion. This is what makes the whole "no extra
prompt" design work. This is wired in **one place** — most likely a global rule
that every edit-making agent obeys — rather than editing each agent
individually. The user's global rule already makes agents state what/where/why
before each edit, so this captures reasoning they already produce. (The
rule-vs-per-agent choice is deferred to the Plan.)

**2. Evidence gatherer (hook side, deterministic — the load-bearing part).**
From stdin (`file_path`, `old_string`, `new_string`) the hook computes, with
plain `rg`/`git` and bounded output:

- **Location** — find `old_string` in the file to get the line range; walk
  upward to the nearest "section-like" line (dashed-rule section label,
  `def`/`fn`/`class`, Markdown heading, Nix `attr =` binding) to name the
  enclosing region.
- **Shape** — new file vs pure addition vs modification; lines added/removed.
- **History** — `git log -1` on the file; `git blame` on the changed lines for a
  modification.
- **Relationships** — extract candidate identifiers from `new_string` (option
  names, attr paths, function/binding names, imports), grep the repo for them,
  and list the top few `file:line` hits **outside** the edited file (this
  change's definitions/consumers).

This block alone satisfies criteria 2, 3, and 4, and is the guaranteed fallback.

**3. Surfacing (hook side).** Print the four-part briefing above the prompt.
Primary channel: `systemMessage`, leaving the permission decision **untouched** —
the hook never allows or denies, it only annotates. Fallback:
`permissionDecision: "ask"` + `permissionDecisionReason` if `systemMessage` does
not render tightly above the prompt. Verified empirically at build time.

### Behavior and edge cases

- **Fail-open.** If the ledger is absent, the lookup misses, or anything errors,
  print the deterministic-only briefing (omit WHY). The hook must **never** block
  or fail an edit; it exits cleanly (non-blocking) in all cases.
- **Quiet on auto-approve.** When the permission mode is `acceptEdits`/`bypass`
  (no prompt will appear), emit nothing — a briefing with no prompt is pure
  noise. If the mode is not readable from hook stdin, verify and degrade
  gracefully. Note the author-side ledger append still happens in every
  permission mode (including `acceptEdits`/`bypass`); that is harmless — only the
  hook's *output* is suppressed on auto-approve.
- **Sandbox-writable ledger path (hard requirement).** The ledger must live on a
  sandbox-writable temp/session path. This is not a cleanup nicety — it is what
  keeps the Bash append prompt-free and hook-free (`autoAllowBashIfSandboxed`
  auto-allows only writes inside the bash sandbox; a ledger under the project
  tree or `~/.claude` would prompt). The ledger is session-scoped (e.g. keyed by
  session id under a temp/session dir) and cleaned up per session.
- **Global scope.** Registered in `settingsPolicy.hooks.PreToolUse` in
  `modules/programs/claude-code/claude-code.nix`, active in **all** projects. The
  hook script ships under `modules/programs/claude-code/config/hooks/` alongside
  the existing hooks, as required by the
  [Claude Code configuration skill](../modules/programs/claude-code/config/skills/claude-code-config/SKILL.md).

### Growth seam

Keep v1 minimal: the briefing formatter is a **single point** with its content
sources (ledger + evidence) behind it, so a future enrichment (e.g. an opt-in
model call) could be added later without reshaping the hook.

### Explicitly rejected alternatives

- **Extra Haiku/API model call from the hook** — the user does not want a
  separate model call, API key, or headless invocation.
- **Injecting text into the accept/deny dialog directly** — impossible; no such
  field, and Edit/Write have no rationale field.
- **Hook calling back into the live session model** — impossible; the model is
  paused awaiting the tool.
- **Deterministic-only with no "why"** — this is the graceful-degradation
  fallback, not the primary design.

### Authorized mechanism (recorded)

The author-side ledger is written by subagents via a **Bash append to a
sandbox-writable temp path** (`$TMPDIR`/`$CLAUDE_CODE_TMPDIR`), deliberately **not**
through the Edit/Write tools. This means it fires neither the `code-writer-gate`
(matcher `Write|Edit|NotebookEdit`) nor this briefing hook (matcher `Edit|Write`),
and stays prompt-free under `autoAllowBashIfSandboxed`. A harness security check
flagged this as routing around the write-gate/hook; the user reviewed that flag and
**explicitly approved it knowingly** — the write-gate governs the reviewability of
main-session *code*, not transient subagent scratch files, and the ledger is
exactly such a scratch file. This authorization is recorded here so the choice is
documented rather than silent.

## Plan

All decisions below are grounded in the live repo and Claude Code 2.1.214
behavior, verified against this repo's working `code-writer-gate` hook and by
directly probing the Bash sandbox and every evidence primitive during planning.

### Resolved open items

**Ledger keying — key on `file_path`, FIFO; a content hash is rejected.** The
author-side rationale is written by a *separate* Bash command whose string cannot
be guaranteed byte-identical to the `new_string` the model later hands to Edit
(whitespace, trailing newline, escaping), so a hash of `new_string` would miss
constantly and the WHY would silently vanish. The `file_path` is the one value
both sides reproduce *exactly* — the model edits the path it named. Protocol: the
author appends **one line per edit, immediately before that edit**; the hook takes
the **first** ledger line matching that path (first-in-first-out) and consumes it.
Multiple edits to one file in a turn stay aligned because each edit is preceded by
its own append. Both sides compute an identical key (the path string), which is
the property the plan-verifier pass required proving.

**Ledger format & path.** A single shared append-log, tab-separated, one line per
pending edit — `<epoch>\t<abs_file_path>\t<one-line rationale>` — at
`${CLAUDE_CODE_TMPDIR:-${TMPDIR:-/tmp}}/claude-edit-briefings/ledger.tsv`. Both
sides derive the path from the identical shell expression.
`$CLAUDE_CODE_TMPDIR`/`$TMPDIR` is the Claude-managed, sandbox-writable temp root
(verified during planning: an append here returned cleanly with no permission
prompt under `autoAllowBashIfSandboxed`). **Not** session-scoped: hook↔subagent
session-id agreement is undocumented for 2.1.214, and scoping by a possibly
mismatched id would make every lookup miss and kill the WHY. The shared log is
robust to that uncertainty; its only cost is a rare mis-attribution if two
*concurrent* sessions edit the *same* path, which degrades to a wrong/absent WHY,
never a blocked edit.

**Cleanup lifecycle.** Consume-on-read (the matched line is removed) plus a prune
of any line older than 12h, both in one atomic rewrite on every hook run. TMPDIR
is itself cleared by the OS across reboots.

**Author-side wiring — a single global rule (not per-agent).** Custom subagents
inherit the full CLAUDE.md hierarchy, including `~/.claude/CLAUDE.md` and
`~/.claude/rules/*.md` (confirmed for 2.1.214 via the sub-agents docs — only the
built-in Explore/Plan agents skip them). Every edit-making agent here
(code-writer, test-writer, doc-writer, comment-writer, spec-writer,
comment-style-enforcer, test-verifier) is custom, so one rule reaches all of them
— no per-agent edits, and it matches the existing rule pattern
(`config/rules/nr-nrr.md`). The user's global CLAUDE.md §5 already makes agents
state what/where/why before each edit, so the rule captures reasoning they already
produce.

**Hook language & gating.** Bash + `jq`, mirroring `code-writer-gate` (tolerate
`jq` absent → fail-open). The hook emits ONLY when every condition holds, else it
exits 0 with no output:
- `jq` present and stdin parses;
- `agent_type` non-empty — a subagent edit, the only kind that reaches a user
  prompt (main-session edits are blocked by `code-writer-gate`). `agent_type` is
  present on PreToolUse in this version, proven by `code-writer-gate` relying on
  it in production;
- `permission_mode == "default"` — quiet on `acceptEdits`/`bypassPermissions`/
  `plan`, where no prompt appears. `permission_mode` is reliably present on
  PreToolUse stdin;
- `file_path` non-empty.

**Surfacing channel — `permissionDecision:"ask"` + `permissionDecisionReason`.**
This **inverts the spec's tentative `systemMessage` default**, on evidence:
`systemMessage` is injected into Claude's context at the next model turn, NOT
rendered at the accept/deny dialog, so it cannot satisfy "above every prompt."
Only `permissionDecisionReason` (with decision `ask`) renders immediately above the
prompt. Because the hook fires solely in `default` mode — where an edit prompts
anyway — returning `ask` changes nothing but the annotation, and the hook never
returns `deny`, so it never blocks an edit. Caveat: if a project allow-lists Edit
so it would auto-run in default mode, `ask` forces a prompt; this setup expects
edit prompts, and the post-rebuild render check (Task 6) confirms behavior. If that
check shows `ask` is undesirable, the documented fallback is `systemMessage`
(accepting it renders in Claude's context rather than at the prompt).

**Evidence gatherer (deterministic, bounded — the load-bearing fallback).** From
stdin:
- **Shape (WHAT)** — from `tool_name`: `Write` to a missing path = new file
  (N lines); `Write` to an existing path = overwrite; `Edit` with empty
  `old_string` = insertion; else modification (+added / -removed line counts).
- **Location (WHERE)** — Edit on an existing file: `grep -nF -m1` the first line of
  `old_string` for line L, then a single forward `awk` pass over lines 1..L reports
  the nearest section-like line at/above L (dashed-rule label, Nix `attr =`
  binding, `def`/`fn`/`func`/`fun`/`class`, or Markdown heading). No `tac` (absent
  on macOS).
- **History (folded into WHERE)** — repo root via `git -C <dir-of-file> rev-parse
  --show-toplevel` (mirrors `agents-md-context`); `git log -1 --format='%h %s
  (%cr)' -- <rel>`; for a tracked modification, one `git blame -L L,L -- <rel>`
  line on the anchor.
- **Relationships (RELATES)** — up to 3 salient identifiers
  (`[A-Za-z_][A-Za-z0-9_]{3,}`, longest-first, minus common shell/Nix keywords)
  from `new_string`/`content`; `rg -n --max-count=2 -F` each across the repo
  excluding the edited file; list up to 5 `file:line` hits.

Every command is bounded (`-m1`, `--max-count`, `head`); any failure is swallowed
(that section is omitted) and the hook always exits 0 (fail-open).

**Registration (array-append, critical).** Add a THIRD entry to the EXISTING
`settingsPolicy.hooks.PreToolUse` array in `claude-code.nix` — keeping the
`ExitPlanMode` and `Write|Edit|NotebookEdit` entries — because the `settingsPolicy`
jq `*` merge replaces arrays wholesale; a standalone entry would silently drop the
existing two hooks. New entry: matcher `"Edit|Write"`, command
`~/.claude/hooks/edit-briefing`.

### Files

1. **New** `modules/programs/claude-code/config/hooks/edit-briefing` — the hook
   script (bash + jq); picked up and marked executable by `readHooks`.
2. **New** `modules/programs/claude-code/config/rules/edit-briefing-ledger.md` —
   the author-side global rule.
3. **Edit** `modules/programs/claude-code/claude-code.nix` — append the third
   `PreToolUse` entry.
4. **Edit** `specs/edit-briefings.md` — this Plan/Tasks + the authorization note
   (done in the planning step); retire the whole file on completion.

### Growth seam

The briefing is assembled by one final formatter block whose only inputs are the
ledger WHY and the computed evidence strings, so a later enrichment (e.g. an
opt-in model call) swaps in behind that single point without reshaping the hook.

## Tasks

Land as one self-contained commit (all three config artifacts ship together; a
hook script without its registration, or a registration without the rule, is
half-wired).

### Task 1 — Ship the hook script

Create `modules/programs/claude-code/config/hooks/edit-briefing` with exactly this
content:

```bash
#!/usr/bin/env bash
# PreToolUse briefing on Edit|Write: prints a compact WHY/WHAT/WHERE/RELATES
# briefing above a subagent's accept/deny prompt. Pure plumbing — the WHY comes
# from the session ledger the acting agent appended (see the edit-briefing-ledger
# rule); the rest is deterministic rg/git evidence. Never blocks or fails an edit:
# every error path exits 0 with no output (fail-open).
set -uo pipefail

input=$(cat)

jq_bin=$(command -v jq || true)
[ -n "$jq_bin" ] || exit 0

j() { "$jq_bin" -r "$1 // empty" <<<"$input" 2>/dev/null || true; }

agent_type=$(j '.agent_type')
permission_mode=$(j '.permission_mode')
tool_name=$(j '.tool_name')
file_path=$(j '.tool_input.file_path')
old_string=$(j '.tool_input.old_string')
new_string=$(j '.tool_input.new_string')
content=$(j '.tool_input.content')

# --- Gate: only a subagent edit that will actually raise a prompt ---
# agent_type is empty for main-session edits (already blocked by code-writer-gate).
# Whitelist "default": only that mode raises a prompt — acceptEdits/bypassPermissions/
# plan auto-approve (a briefing there is noise), and an unreadable mode must stay
# quiet too, since a "ask" payload would force a prompt inside an auto-approve run.
[ -n "$agent_type" ] || exit 0
[ "$permission_mode" = "default" ] || exit 0
[ -n "$file_path" ] || exit 0

L=""
root=""
rel=""
where=""
rels=""
why=""

count_lines() { [ -z "$1" ] && echo 0 || printf '%s\n' "$1" | wc -l | tr -d ' '; }

# --- WHAT: change shape ---
src="${new_string:-$content}"
added=$(count_lines "$src")
removed=$(count_lines "$old_string")
if [ "$tool_name" = "Write" ]; then
  [ -f "$file_path" ] && shape="overwrites existing file (${added} lines)" \
    || shape="creates new file (${added} lines)"
elif [ -z "$old_string" ]; then
  shape="inserts ${added} line(s)"
else
  shape="modifies: +${added} / -${removed} line(s)"
fi

# --- WHERE: anchor line + nearest enclosing section (single forward awk pass) ---
# Best-effort: matches only old_string's FIRST line, so a repeated first line can
# report an earlier location. Evidence-only — never affects whether the edit runs.
if [ "$tool_name" = "Edit" ] && [ -f "$file_path" ] && [ -n "$old_string" ]; then
  first_line=$(printf '%s\n' "$old_string" | head -1)
  L=$(grep -nF -m1 -e "$first_line" "$file_path" 2>/dev/null | cut -d: -f1 || true)
  if [ -n "$L" ]; then
    sec=$(awk -v L="$L" '
      NR>L{exit}
      /^[[:space:]]*#[[:space:]]*-{3,}/{s=$0}
      /^[[:space:]]*[A-Za-z_][A-Za-z0-9_.-]*[[:space:]]*=/{s=$0}
      /^[[:space:]]*(def|fn|func|fun|class)[[:space:]]/{s=$0}
      /^#{1,6}[[:space:]]/{s=$0}
      END{if(s)print s}' "$file_path" 2>/dev/null | sed 's/^[[:space:]]*//' || true)
    where="line ${L}${sec:+, in: ${sec}}"
  fi
fi

# --- WHERE (provenance): last change to the file + blame on the anchor line ---
root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null || true)
if [ -n "$root" ]; then
  rel=${file_path#"$root"/}
  last=$(git -C "$root" log -1 --format='%h %s (%cr)' -- "$rel" 2>/dev/null || true)
  [ -n "$last" ] && where="${where:+$where; }last change: ${last}"
  if [ -n "$L" ] && [ "$tool_name" = "Edit" ]; then
    bl=$(git -C "$root" blame -L "${L},${L}" -- "$rel" 2>/dev/null | head -1 | cut -c1-72 || true)
    [ -n "$bl" ] && where="${where}; blame: ${bl}"
  fi
fi

# --- RELATES: top identifiers from the new text, grepped outside the edited file ---
rg_bin=$(command -v rg || true)
if [ -n "$rg_bin" ] && [ -n "$src" ] && [ -n "$root" ]; then
  idents=$(printf '%s\n' "$src" | grep -oE '[A-Za-z_][A-Za-z0-9_]{3,}' \
    | sort -u | awk '{print length, $0}' | sort -rn | awk '{print $2}' \
    | grep -vE '^(true|false|null|import|return|const|function|config|inherit|lib|pkgs|with|then|else|self|type|name|args|command)$' \
    | head -3 || true)
  # Exclude the edited file only when it is under $root (else the prefix strip
  # leaves rel absolute and the glob would fail to exclude it).
  [ "$rel" != "$file_path" ] && exclude=(-g '!'"$rel") || exclude=()
  hits=""
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    h=$("$rg_bin" -n --max-count=2 -F -e "$id" "$root" "${exclude[@]}" 2>/dev/null | head -2 || true)
    [ -n "$h" ] && hits="${hits}${h}"$'\n'
  done <<<"$idents"
  rels=$(printf '%s' "$hits" | head -5)
fi

# --- WHY: first ledger line for this path; consume it and prune entries >12h ---
led="${CLAUDE_CODE_TMPDIR:-${TMPDIR:-/tmp}}/claude-edit-briefings/ledger.tsv"
if [ -f "$led" ]; then
  why=$(awk -F'\t' -v p="$file_path" '$2==p{print $3; exit}' "$led" 2>/dev/null || true)
  cutoff=$(( $(date +%s) - 43200 ))
  tmp="${led}.$$"
  if awk -F'\t' -v p="$file_path" -v c="$cutoff" '
      BEGIN{done=0}
      { if(!done && $2==p){done=1; next} if($1+0 >= c) print }' "$led" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$led" 2>/dev/null || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
fi

# --- Assemble and surface (single formatter — the growth seam) ---
briefing="Edit briefing (${agent_type})"
[ -n "$why" ]   && briefing="${briefing}"$'\n'"WHY: ${why}"
briefing="${briefing}"$'\n'"WHAT: ${shape}"
[ -n "$where" ] && briefing="${briefing}"$'\n'"WHERE: ${file_path} (${where})"
[ -n "$rels" ]  && briefing="${briefing}"$'\n'"RELATES:"$'\n'"${rels}"

"$jq_bin" -n --arg r "$briefing" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
exit 0
```

### Task 2 — Ship the author-side rule

Create `modules/programs/claude-code/config/rules/edit-briefing-ledger.md` with
exactly this content:

```markdown
# Edit-briefing ledger

Before **every** `Edit` or `Write` tool call, first append a one-line rationale to
the session edit-briefing ledger with a Bash command. A global `PreToolUse` hook
(`edit-briefing`) reads that line and shows it as the WHY above the user's
accept/deny prompt for the edit. This surfaces the what/where/why you already state
before each edit (CLAUDE.md §5) at the exact moment the user judges it.

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
```

### Task 3 — Register the hook (append to the existing array)

In `modules/programs/claude-code/claude-code.nix`, in `settingsPolicy.hooks`,
append a third entry to the existing `PreToolUse` array (keep the two existing
entries intact):

```nix
        PreToolUse = [
          {
            matcher = "ExitPlanMode";
            hooks = [(cmd "~/.claude/hooks/plan-verifier-gate")];
          }
          {
            matcher = "Write|Edit|NotebookEdit";
            hooks = [(cmd "~/.claude/hooks/code-writer-gate")];
          }
          {
            matcher = "Edit|Write";
            hooks = [(cmd "~/.claude/hooks/edit-briefing")];
          }
        ];
```

### Task 4 — Stage the new files

`git add` both new files so the flake eval sees them (untracked files are invisible
to the build):

```sh
git -C /etc/nix-darwin add \
  modules/programs/claude-code/config/hooks/edit-briefing \
  modules/programs/claude-code/config/rules/edit-briefing-ledger.md
```

### Task 5 — Hook unit checks (no rebuild needed; run the script directly)

The hook is standalone bash, so drive it with synthetic stdin and assert:

- **Emits for a default-mode subagent Edit.** Pipe JSON with `agent_type:"code-writer"`,
  `permission_mode:"default"`, `tool_name:"Edit"`, a real `file_path`, and an
  `old_string` present in that file; assert stdout is JSON with
  `.hookSpecificOutput.permissionDecision == "ask"` and a non-empty
  `permissionDecisionReason` containing `WHAT:`.
- **Quiet on auto-approve.** Same JSON but `permission_mode:"acceptEdits"` →
  empty stdout, exit 0. Repeat for `bypassPermissions` and `plan`.
- **Quiet for main-session edit.** Omit `agent_type` → empty stdout, exit 0.
- **WHY appears when ledger has a matching line.** Append a line for that
  `file_path` to `${CLAUDE_CODE_TMPDIR:-${TMPDIR:-/tmp}}/claude-edit-briefings/ledger.tsv`,
  run the hook, assert `permissionDecisionReason` contains `WHY:` and that the line
  was consumed (a second run for the same path shows no `WHY:`).
- **Fail-open.** Feed malformed/empty stdin → exit 0, empty stdout.

### Task 6 — Build validation and empirical render check

Dry-build the darwin hosts that install this config (run Nix with the sandbox
disabled — `nix flake check`/`build` need `~/.cache/nix`, which the command sandbox
blocks):

```sh
nix flake check
nix build .#darwinConfigurations.aspen.system --no-link
nix build .#darwinConfigurations.cedar.system --no-link
nix build '.#homeConfigurations."jake.neau@cedar".activationPackage' --no-link
```

The Bash-append-is-prompt-free requirement was verified during planning (an append
to `${CLAUDE_CODE_TMPDIR:-${TMPDIR:-/tmp}}/claude-edit-briefings/` completed with no
permission prompt under `autoAllowBashIfSandboxed`).

**Render check (interactive, post-rebuild — for the user).** After rebuilding,
have a subagent make one edit in `default` mode and confirm the four-part briefing
renders immediately above the accept/deny prompt. If `permissionDecision:"ask"`
misbehaves (double-prompt, or a prompt where Edit was allow-listed), switch the
final `jq` output to a `systemMessage` payload (the documented fallback) and
rebuild.

### Task 7 — Retire the spec

Once implemented, documented, and the review is clean, delete
`specs/edit-briefings.md` in full (transient scaffolding). No project docs system
covers Claude Code hook internals, so there is no reference page to update in its
place; note that at hand-off.
