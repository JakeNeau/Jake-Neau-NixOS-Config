# Code-review gates (`SubagentStop` transcript inspection)

> Status: **design, pre-implementation.** Refine over further prompts, then
> implement and delete per the specs lifecycle
> (`modules/programs/claude-code/config/skills/specs/SKILL.md`). This is the
> **second** design for this problem — the first (session-keyed marker files) was
> implemented, tested live, and abandoned; see **Rejected approach** below so we
> never repeat it. The core mechanics of this design are **empirically
> confirmed** (see the confirmed-facts callout under Spec), not assumed.

## Spec

### The problem (unchanged)

Two mandatory review steps in this repo's Claude Code agent flow are enforced
**only by prose** in the agent prompts, so a non-compliant run can finish anyway:

- **`code-writer`** is told to loop `code-reviewer` over its changes until the
  verdict is clean (`config/agents/code-writer.md:159-170`), but nothing stops it
  returning with no review at all.
- **`code-reviewer`** is told to dispatch `comment-style-enforcer` over the
  changed files (`config/agents/code-reviewer.md:79-84`), but nothing stops it
  skipping that pass.

We harden both with **two `SubagentStop` hooks**. This is the same
enforcement-by-hook spirit already used for plan verification
(`config/hooks/plan-verifier-gate`) and direct-write blocking
(`config/hooks/code-writer-gate`), extended to the `SubagentStop` event.

### The settled design: transcript inspection

`SubagentStop` fires when a subagent finishes, with a JSON payload on stdin
carrying `agent_type` (the stopping agent's frontmatter `name:`) and
`agent_transcript_path` (the absolute path to *that agent's own* transcript). Each
hook early-exits (allow) unless `agent_type` matches the agent it guards, then
**reads the stopping agent's own transcript and parses it for tool-use entries**
that prove the required sub-dispatch happened. Nothing is written by any agent;
the transcript is the record, and the hook is a read-only observer of it.

The block message instructs a non-compliant agent on exactly what to do; once it
does it, its transcript records the dispatch and the retry passes. This is
**self-resolving** with no marker to write, no path to relay, and no agent-prompt
change.

**Loop guard.** A block that the agent cannot satisfy (it disagrees, runs out of
budget, or the dispatch itself errors) must not wedge it in an endless
block/retry spiral — that is exactly the inescapable-obstacle dynamic that made
the rejected design spiral for ~80 minutes. `SubagentStop` payloads carry
`stop_hook_active`, which the harness sets `true` once a stop hook has already
fired and blocked this stop. **Both gates block at most once:** if
`stop_hook_active` is already `true`, the gate surrenders (exit 0, allow) rather
than block again. One nudge, then get out of the way.

> **Empirically confirmed today (do NOT re-flag as unverified):**
> - `SubagentStop` **fires** for nested subagents (bottom-up). Its stdin payload
>   includes `session_id`, `agent_type` (== the agent's frontmatter `name:`),
>   `transcript_path`, `agent_transcript_path`, `permission_mode`,
>   `stop_hook_active`, `last_assistant_message`.
> - Exit code **2** from a `SubagentStop` hook **blocks the stop** and the stderr
>   is fed back to the agent, which retries.
> - A **matcher-less** `SubagentStop` registration is accepted at runtime.
> - Transcript files are **JSONL** (one JSON object per line). Assistant tool
>   calls appear as `.message.content[]` entries with `.type=="tool_use"` and a
>   `.name` (`"Write"`, `"Edit"`, `"NotebookEdit"`, `"Agent"`, …); for an `Agent`
>   dispatch, `.input.subagent_type` names the spawned agent.
> - Each subagent transcript has a sibling `<file>.meta.json`
>   (`{agentType, description, toolUseId, spawnDepth}`) — an alternative identity
>   source, though `agent_type` in the payload already suffices.
> - Verified against real fixtures under
>   `~/.claude/projects/-private-etc-nix-darwin/<session>/subagents/agent-*.jsonl`
>   left by today's runs.

**Gate A — `code-writer` must have dispatched `code-reviewer` when it made edits.**
Guards `agent_type == "code-writer"`.
- **`stop_hook_active == true`** → **ALLOW** (already blocked once; surrender —
  the loop guard).

Otherwise, reading its transcript:
- **No `Write`/`Edit`/`NotebookEdit` tool-use** → **ALLOW.** A code-writer run
  with no edits is legitimate — plan-only work and investigation (global rule 7 /
  plan mode ask code-writer for a verified plan only), which has nothing to
  review. **This conditional is required**; without it, every plan-only run is
  falsely blocked.
- **Edits present AND an `Agent` tool-use with `subagent_type == "code-reviewer"`**
  → **ALLOW.**
- **Edits present but NO `code-reviewer` dispatch** → **BLOCK** (exit 2). Stderr
  instructs: dispatch `code-reviewer` on your changes, then retry stopping.
  Self-resolving — the dispatch is recorded in the transcript and the retry passes.

**Gate B — `code-reviewer` must have dispatched `comment-style-enforcer`.**
Guards `agent_type == "code-reviewer"`.
- **`stop_hook_active == true`** → **ALLOW** (surrender — the loop guard).

Otherwise, reading its transcript:
- **An `Agent` tool-use with `subagent_type == "comment-style-enforcer"`** →
  **ALLOW**; else **BLOCK** (exit 2) instructing it to run the comment pass, then
  retry. **Unconditional** — the comment pass is always part of code-reviewer's
  job, and on a diff with no comments it is a harmless no-op
  (`config/agents/code-reviewer.md:79-84`).

### No agent-prompt edits (explicit)

This design touches **no agent prompt.** The agents already instruct these
dispatches (`code-writer.md:159-170`, `code-reviewer.md:79-84`); the gate only
enforces what the prose already says, and the block message alone handles a
non-compliant run by telling it what to dispatch and to retry. This is the sharpest
contrast with the rejected design, which required threading a marker path through
three agent prompts.

### Detection mechanics

- **Primary — jq.** Scan every line of the transcript and collect the tool-use
  facts, mirroring the tolerant `command -v jq || true` pattern in
  `plan-verifier-gate:11` and `code-writer-gate:13`. Two questions per gate:
  - "did it edit?" — any line with
    `.message.content[]? | select(.type=="tool_use") | .name` in
    `Write`/`Edit`/`NotebookEdit`.
  - "did it dispatch agent X?" — any line with
    `.message.content[]? | select(.type=="tool_use" and .name=="Agent") | .input.subagent_type`
    equal to `code-reviewer` / `comment-style-enforcer`.
- **Fallback — grep, when jq is absent.** A line-grep for the compact serialized
  key form is serviceable: the `Agent` tool serializes as
  `"subagent_type":"code-reviewer"` (no space after the colon — confirmed in real
  fixtures). Match both `"subagent_type":"code-reviewer"` and
  `"subagent_type": "code-reviewer"` to be robust to pretty-printed variants, and
  for the edit check grep for `"name":"Write"` / `"Edit"` / `"NotebookEdit"` (and
  the spaced form). The fallback is best-effort, exactly as the jq-absent paths in
  the two existing gates are. **Known false-ALLOW direction:** the line-grep matches
  the literal key string anywhere, so a transcript that merely *contains*
  `"subagent_type":"code-reviewer"` without a real dispatch — e.g. a `code-writer`
  editing these hook files, their fixtures, or this spec — would pass the fallback.
  It fails **open**, consistent with the gates' fail-open stance; `jq` is present on
  this machine so the primary path is unaffected. Recorded, not fixed.
- **Why reading the transcript works where the marker WRITE failed.** Hooks run at
  the **harness level**, not inside the command sandbox, so reading files under
  `~/.claude/projects/...` is unrestricted. The rejected design failed precisely
  because a *sandboxed* subagent's `touch` under `~/.claude` landed in a sandbox
  overlay and never reached the real filesystem. Reading, from the harness,
  sidesteps that entirely.

### Rejected approach: session-keyed marker files (implemented, then abandoned)

The first design had `code-reviewer` / `comment-style-enforcer` **write a
per-session marker file** under `~/.claude/code-review-gate/` that the
`SubagentStop` hook consumed (delete-on-read for freshness), with the hook
emitting the resolved path in its block message and each agent relaying that path
into the sub-dispatch's prompt. It was implemented, activated, and tested live,
and **failed three ways**:

1. **Sandbox overlay swallowed the write.** `~/.claude` is **outside the command
   sandbox's writable root**, so a sandboxed subagent's `touch` silently landed in
   a sandbox overlay and *falsely reported success* — the marker never appeared on
   the real filesystem, so the gate re-blocked on retry. The whole mechanism
   depended on a sandboxed write that could not happen.
2. **The gate induced bypass-framing.** The safety classifier keys on *intent*,
   and a block the agent experiences as an obstacle to escape reads as tunneling:
   the agent's marker-writing and re-dispatch attempts got denied as
   "forging"/"tunneling" a gate. Converging on the honest path took **~80 minutes
   for a trivial task**.
3. **`session_id` was not stable across the nested tree**, so the session key the
   marker path was built from did not reliably line up between the writing agent
   and the gating hook.

**Transcript inspection avoids all three:** agents write nothing (no sandboxed
write to lose), there is no signal to forge or block to escape (the agent just
does its normal job and retries), and `agent_transcript_path` is **per-instance**
— no session key to get wrong.

### Accepted limitations (record)

- **"Invoked at least once," not "final state reviewed."** The gate proves the
  reviewer was *dispatched*, not that the *final* diff was the one reviewed. This
  invoked-level rigor is the deliberate choice; the clean-vs-final loop stays the
  prompts' job (`code-writer.md:166-170`).
- **Bash-only edits are invisible.** Edits made through `Bash` (`sed` etc.) rather
  than the `Write`/`Edit`/`NotebookEdit` tools would not register as "edits" in
  Gate A. Atypical for these agents; not a tamper boundary.
- **Not tamper-proof.** An agent could dispatch a token reviewer and ignore its
  verdict; the gate cannot tell. Out of scope — this is a forcing function against
  accidental skips, the same threat model as `plan-verifier-gate`, not a security
  boundary.

### Out of scope — not goals

- **Replacing `comment-style-enforcer-reminder`.** That `PostToolUse`-on-
  `ExitPlanMode` hook (`config/hooks/comment-style-enforcer-reminder`, registered
  at `claude-code.nix:94-101`) reminds the **main session** to run the comment
  pass over plan-mode edits when `code-writer` is not the implementer. Gate B is
  independent: it enforces the pass **inside** a `code-reviewer` subagent run.
  Different actors; no conflict; keep both.

## Plan

All paths are under `/private/etc/nix-darwin/modules/programs/claude-code/`. Both
hook scripts are modeled on the two existing gates: `set -euo pipefail`, read
stdin into `input`, resolve `jq` tolerantly (`plan-verifier-gate:6-13`,
`code-writer-gate:5-16`), parse fields with `.field // empty`, early-exit `0` for
any agent this gate does not guard, and on the failure path `cat >&2` a short
instruction and `exit 2` (`plan-verifier-gate:26-38`, `code-writer-gate:29-36`).
Each carries the same short why-comment header style
(`config/skills/comments`).

### 1. Hook script — `config/hooks/code-review-writer-gate` (Gate A)

New executable bash file:
- Parse `agent_type`, `agent_transcript_path`, and `stop_hook_active` from
  `input` (`.agent_type // empty`, `.agent_transcript_path // empty`,
  `.stop_hook_active // false`).
- **Early-exit 0** unless `agent_type == "code-writer"`.
- **`stop_hook_active == true`** → exit 0 (loop guard: block at most once, then
  surrender rather than wedge the agent).
- **Missing/unreadable transcript** → exit 0 (fail-open, like the jq-absent paths
  in the existing gates: never wedge a legitimate stop on a read failure).
- Compute two booleans from the transcript (jq primary, grep fallback per
  Detection mechanics):
  - `has_edits` — any `Write`/`Edit`/`NotebookEdit` tool-use.
  - `has_review` — any `Agent` tool-use with `subagent_type == "code-reviewer"`.
- **`has_edits == false`** → exit 0 (plan-only run; nothing to review — the
  required conditional).
- **`has_edits && has_review`** → exit 0.
- **`has_edits && !has_review`** → `cat >&2` a message: this code-writer made file
  edits but never dispatched `code-reviewer`; dispatch `code-reviewer` on your
  changes, then stop again. `exit 2`.

### 2. Hook script — `config/hooks/code-review-comments-gate` (Gate B)

New executable bash file, same skeleton:
- **Early-exit 0** unless `agent_type == "code-reviewer"`.
- **`stop_hook_active == true`** → exit 0 (loop guard).
- **Missing/unreadable transcript** → exit 0 (fail-open).
- `has_comment_pass` — any `Agent` tool-use with
  `subagent_type == "comment-style-enforcer"`.
- **`has_comment_pass`** → exit 0.
- **else** → `cat >&2`: this code-reviewer never dispatched
  `comment-style-enforcer`; run the comment pass over the changed files, then stop
  again. `exit 2`.

### 3. Nix registration — `claude-code.nix`

In `settingsPolicy.hooks` (`claude-code.nix:77-103`), add a **new matcher-less
`SubagentStop` event** alongside the existing `PreToolUse`/`PostToolUse` blocks,
reusing the `cmd` helper (`claude-code.nix:78-82`):

```nix
SubagentStop = [
  {
    hooks = [
      (cmd "~/.claude/hooks/code-review-writer-gate")
      (cmd "~/.claude/hooks/code-review-comments-gate")
    ];
  }
];
```

No `matcher` (SubagentStop has no tool matcher; each hook self-filters on
`agent_type` — matcher-less registration is confirmed accepted). The `readHooks`
helper (`claude-code.nix:39-42`) auto-inlines any new file in `config/hooks/`, so
no other wiring is needed. Honor the in-file caveat (`claude-code.nix:74-76`):
jq's `*` merge replaces arrays wholesale, so this `SubagentStop` array must list
the **complete** set — both hooks together.

**Additive-merge removal gotcha (record for the future).** The activation
merge is `jq '. * $policy'` (`claude-code.nix:268-269`) — purely *additive* into
the live `~/.claude/settings.json`. If these hooks are ever **removed** from the
Nix config later, a rebuild alone will **not** unregister them: the stale
`SubagentStop` block persists in the live settings file. Removal must also
jq-delete the block from `~/.claude/settings.json` directly (or reset the file).

### 4. No agent-prompt edits

Explicitly, this plan changes **no** `config/agents/*.md`. The dispatches are
already prescribed (`code-writer.md:159-170`, `code-reviewer.md:79-84`) and the
block messages instruct any non-compliant run. Do not edit the agents.

### 5. Test each hook branch against real transcript fixtures

Unit-test each branch by piping a synthetic `SubagentStop` JSON payload (with
`agent_transcript_path` pointing at a fixture) into the hook and asserting exit
code + stderr. Today's runs left usable fixtures under
`~/.claude/projects/-private-etc-nix-darwin/<session>/subagents/`:

Gate A:
- **ALLOW (edits + review):** the confirmed code-writer transcript
  `.../d854889e-877c-4c32-9324-de97f2bd599e/subagents/agent-a26b8959494e65155.jsonl`
  — verified to contain a `Write` tool-use *and* seven `code-reviewer` `Agent`
  dispatches. Payload `agent_type:"code-writer"` → expect exit 0.
- **ALLOW (no edits):** synthesize a fixture (or pick a code-writer/investigation
  transcript) with no `Write`/`Edit`/`NotebookEdit` line → expect exit 0.
- **BLOCK (edits, no review):** synthesize from the ALLOW fixture by stripping
  every `Agent`/`code-reviewer` line while keeping the `Write` line → expect exit
  2 and the "dispatch code-reviewer" stderr.
- **Skip (wrong agent):** payload `agent_type:"doc-writer"` → expect exit 0
  regardless of transcript.

Gate B:
- **ALLOW:** the confirmed code-reviewer transcript
  `.../d854889e-877c-4c32-9324-de97f2bd599e/subagents/agent-a4a26afc42fa26a0b.jsonl`
  — verified (meta `agentType:"code-reviewer"`) to dispatch `comment-style-enforcer`.
  Payload `agent_type:"code-reviewer"` → expect exit 0. (More such fixtures exist
  in that tree via `grep -l '"subagent_type":"comment-style-enforcer"'`.)
- **BLOCK:** a code-reviewer transcript lacking that dispatch → expect exit 2 and
  the "run comment pass" stderr.
- **Skip (wrong agent):** any non-`code-reviewer` `agent_type` → exit 0.

Also test:
- **Loop guard:** a would-BLOCK payload (Gate A edits-no-review fixture; Gate B
  no-comment-pass fixture) but with `stop_hook_active: true` → exit 0 (both gates
  surrender after one block).
- **Fail-open:** a payload whose `agent_transcript_path` points at a nonexistent
  file → exit 0 (both gates).
- **Grep fallback:** run each hook with `jq` shadowed out of `PATH` against the
  same fixtures and assert the same verdicts.

### 6. Validate the build

Per `CLAUDE.md` ("Validating changes"): `git add` the two new hook files and the
edited `claude-code.nix` (untracked files are invisible to flake eval — see
MEMORY), then, with `dangerouslyDisableSandbox: true` (nix eval/build needs
`~/.cache/nix`, blocked by the sandbox — see MEMORY):
- `nix flake check`
- `nix build .#darwinConfigurations.cedar.system --no-link`

Confirm both succeed. Do **not** `switch` or run `nr`/`nrr`.

## Tasks

1. **Write Gate A hook** `config/hooks/code-review-writer-gate` — conditional on
   edits (Plan §1), modeled on `plan-verifier-gate`/`code-writer-gate`.
2. **Write Gate B hook** `config/hooks/code-review-comments-gate` — unconditional
   comment-pass check (Plan §2).
3. **Test both hooks** against the real fixtures and synthesized cases (Plan §5):
   every branch of each gate, the fail-open path, and the grep fallback. Prove the
   asserted exit codes + stderr before wiring anything live.
4. **Register both** under a new matcher-less `SubagentStop` block in
   `claude-code.nix:settingsPolicy.hooks` (Plan §3), recording the additive-merge
   removal gotcha as an in-file comment near the block.
5. **Validate**: `git add`, then `nix flake check` and the cedar darwin dry-build
   (sandbox disabled) (Plan §6). Surface any failure; do not `switch`.

No agent-prompt edits (Plan §4). Tasks 1–3 (write + test the hooks) may land as
one commit since a hook is inert until registered; task 4 makes them live and task
5 proves the module still evaluates.
