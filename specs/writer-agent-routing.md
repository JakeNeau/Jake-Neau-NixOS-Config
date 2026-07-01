# Writer-agent routing (blocking toggle-gate `code-writer-gate`)

> Status: **design, pre-implementation.** Refine over further prompts, then
> implement and delete per the specs lifecycle
> (`modules/programs/claude-code/config/skills/specs/SKILL.md`). Separate from
> `specs/code-review-gates.md`, which covers unrelated `SubagentStop` review
> gates. This spec **revises an already-live hook** (`code-writer-gate`, built in
> Generations 130–132), so it changes behavior in production — the consequential
> changes below need explicit reconfirmation before implementing.

## Spec

### The change

Turn `code-writer-gate` from an **all-or-nothing hard block** (block every direct
main-session write, allow every subagent write) into a **per-agent toggle gate**
that **blocks every write exactly once** for a routing judgment, lets the retry
proceed, then re-arms for the next write — for **all** actors, main session and
writer subagents alike.

Today the hook (`modules/programs/claude-code/config/hooks/code-writer-gate`)
`exit 2`-blocks any direct main-session write and unconditionally allows any
subagent write: it allows only when `agent_type` is present (a subagent) or the
path is under `~/.claude` (a `..`-guarded carve-out for Claude's own plan/memory
files). Under this spec it still **blocks with `exit 2`** — the same blocking
mechanism the current hook already uses — but now on **every** write, gated by a
per-agent *armed* flag so the block fires once per edit without ever looping.

### The mechanism — a per-agent armed toggle

`PreToolUse` cannot natively tell a first attempt from a retry: the same
`Write`/`Edit` fires the hook again identically after an `exit 2` block. The gate
supplies the missing retry-discriminator itself with a single boolean of
**hook-managed state** per acting agent: an *armed* flag.

The flag lives in a **harness-side state file** that **the hook itself writes**.
Hooks run at the harness level, **not** inside the command sandbox
(`specs/code-review-gates.md`, "Rejected approach" point 1 / "Detection
mechanics"), so this write has none of the sandbox-overlay/forge problems that
sank the marker design — there is no *agent* being asked to write anything. This
directly mirrors `plan-verifier-gate`, which already keeps per-session marker
files under `~/.claude/plan-verifier-gate/` and writes/deletes them from the hook
(`plan-verifier-gate:16-25`).

**Keying.** The flag is keyed by the **acting agent**: the payload's `agent_id`
for a subagent, or `session_id` for the main session (Task 1's probe confirms
exactly which fields `PreToolUse` carries and which identifies the main session).
Use `agent_id` when present, else `session_id`, else a literal `unknown`
fallback (the `plan-verifier-gate:14` pattern).

**Per Write/Edit/NotebookEdit call:**

- **Exempt paths** (see Exemptions) → **ALLOW silently (exit 0), and do NOT touch
  the toggle.** An exempt write must not consume the armed slot, or it would leave
  the gate disarmed and let the *next* real write slip through unprompted.
- **Armed** → **BLOCK (exit 2)** with the agent-aware judgment message (below),
  and set the flag **disarmed**.
- **Disarmed** → **ALLOW (exit 0)**, and set the flag **armed** again — "the gate
  closes after the edit."

The default state of an unseen key is **armed**, so the very first write of a
session/agent is gated.

**Why this never loops.** A block always disarms the flag, so the immediate retry
of the *same* write finds the flag disarmed and passes (exit 0), which re-arms it
for the next write. Each edit costs exactly one block + one allowed retry; there
is no state in which the same write is blocked twice in a row. The toggle *is* the
retry-discriminator `PreToolUse` lacks natively.

### The block message is agent-aware (keyed on `agent_type`)

The payload's `agent_type` is empty for a main-session write and equals the
subagent's frontmatter `name:` for a delegated one (confirmed by today's sibling
work; Task 1 re-confirms it lands in the `PreToolUse` payload specifically). Two
messages, both worded so that **retrying reads as the sanctioned, expected way to
proceed** — never as escaping or bypassing a gate:

- **Main session (`agent_type` empty):** "You are not a writer agent. Judge which
  writer fits this file — `code-writer` (code), `doc-writer` (documentation),
  `spec-writer` (specs), `test-writer` (tests) — and delegate to it. If the change
  is very small and immediately obvious, simply retry this edit to proceed —
  retrying is expected and sanctioned, not a bypass."
- **A writer subagent (`agent_type` is one of the four writers):** "You are
  already `<agent_type>`. If you are the right writer for this file, simply retry
  to proceed — do NOT spawn a duplicate of yourself. If this file is outside your
  lane, delegate to the right writer. Retrying is the sanctioned way to proceed."

The retry-is-sanctioned framing is **deliberate and load-bearing.** The rejected
marker design spiraled for ~80 minutes because the safety classifier keys on
intent and read "escaping a block" as tunneling/forging a gate
(`specs/code-review-gates.md`, "Rejected approach" point 2). This gate has Claude
retry past a `Write`-block on *every* edit, so it is *more* classifier-exposed, not
less — Task 1 must prove the retry stays clear of that flagging (see the probe).
Wording the retry as the intended, blessed path is the mitigation.

Firing for **both** actors is the point: the subagent-facing text is the "note
which agent you're in, don't spawn a duplicate of yourself" self-check. For any
`agent_type` that is a **non-writer** subagent (e.g. `codebase-investigator`,
which cannot write anyway, or an agent editing legitimately), the same
writer-subagent message is serviceable — it keys on "are you the right writer for
this file," which any agent can answer — so it stays **one code path**, not a
growing per-agent table.

**Writer set is exactly:** `code-writer`, `doc-writer`, `spec-writer`,
`test-writer`. Deliberately **not** `comment-writer` / `comment-style-enforcer` —
those are sub-delegated *inside* `code-writer`/`code-reviewer`
(`config/agents/code-reviewer.md:79-84`), not main-session routing targets.

### Optional path hint

The block message MAY append a heuristic hint of the likely-fitting writer from
the `file_path`: `specs/` → `spec-writer`; a docs tree → `doc-writer`; a test path
→ `test-writer`; else `code-writer`. The hint aids the judgment; **Claude makes
the final call** regardless. Hints are heuristic and may misfire on ambiguous
files (recorded as an accepted limitation).

### Exemptions (allow silently; never touch the toggle)

- **`~/.claude/*`** — Claude's own plan-mode plans, auto-memory, and task state
  aren't project files. Preserve the current carve-out's spirit, including its
  `..`-traversal guard (`code-writer-gate:22-27`): reject any path containing
  `..` before matching the prefix, since a traversal can start under `~/.claude`
  yet resolve outside it.
- **The session scratchpad** — under the harness temp root. Match the two
  **leading-anchored** globs `/private/tmp/claude-*` and `/tmp/claude-*` (the
  macOS `/tmp`→`/private/tmp` symlink means either prefix appears). The hook can't
  know the exact per-session subpath, so it anchors on the temp root. **Never** a
  floating `*claude-*` — that would exempt any project path containing the
  substring `claude-`, including this very repo's `.../claude-code/...` tree.

A single leading `..`-reject precedes **all** exemption matches (the `~/.claude`
match *and* both scratchpad matches), so a traversal that starts under an exempt
prefix but resolves outside it is never exempted — one `case` handling `*..*`
first, then `"$HOME"/.claude/*`, then the two anchored scratchpad prefixes. An
exempt match returns immediately (`exit 0`) **before any toggle read or write**.

### The uncertain mechanism — why Task 1 gates everything

The design turns on one empirical unknown that is **make-or-break**:

**Does the block→retry cycle, on *every* edit, stay clear of the auto-mode safety
classifier's "bypass/tunneling" flagging?** The marker design was wrecked
precisely because retrying past a gate read to the classifier as tunneling
(`specs/code-review-gates.md`, "Rejected approach" point 2), and this toggle has
Claude retry past a `Write`-block on *every single edit* — potentially even more
classifier-exposed than the marker design was. If re-issuing a `Write` immediately
after a `PreToolUse` `exit 2` block gets flagged or denied rather than proceeding
smoothly, this design will thrash exactly like the marker one. **Task 1 is a
throwaway probe that gates the whole build**; if the retry is flagged, **stop and
revisit with the user** — the toggle mechanism may be infeasible and a different
approach (or keeping the current hard block) is needed.

### Consequential changes — reconfirm at review

1. **Softens the hard delegation guarantee** built in Generations 130–132. Under
   the current hook a direct main-session write is *impossible*. Under the toggle
   it is **gated but satisfiable by retry**: after one block, a determined direct
   write always gets through. Such trivial main-session edits (retry-past-gate)
   also **bypass the `SubagentStop` code-review gates** (`specs/code-review-gates.md`)
   entirely, since those gates only fire inside `code-writer`/`code-reviewer`
   subagent runs. Intended — the gate becomes a forcing function to *judge* each
   edit, not an absolute wall — but it is a real loosening of a guarantee that
   currently holds absolutely, and must be reconfirmed.

2. **Global CLAUDE.md rule 7 becomes inaccurate.** `config/CLAUDE.md` §7 currently
   states a PreToolUse hook "blocks direct main-session file writes, so every
   change — even a one-line edit — must go through a subagent." Under the toggle
   model that is untrue (a retry proceeds). Rule 7 must be reworded to the
   toggle-gate model: a PreToolUse hook that blocks each write once for a routing
   judgment, satisfiable by delegating to the right writer or — for a very small,
   obvious change — by retrying directly. Keep the rest of §7 (delegate non-trivial
   work; pass full context; relay questions) intact — the delegation *norm*
   survives; only the *absolute-block* claim changes. See Plan §4.

3. **A second hook references the hard block.** `code-writer-plan-reminder`
   (`config/hooks/code-writer-plan-reminder:9`, and its header at ~line 3) tells
   Claude post-plan-approval that "Direct writes are blocked by a PreToolUse hook
   (CLAUDE.md §7), so delegation is mandatory." That claim becomes inaccurate and
   must be reworded to match the toggle model (still steer plan implementation to
   `code-writer`, but without asserting an absolute block). See Plan §4.

### Accepted limitations / wrinkles (record)

- **Wrong-file-after-block slips through.** If, after a block, Claude writes a
  **different** file instead of retrying the blocked one, that different write
  finds the flag disarmed and slips through unprompted. The toggle **self-corrects
  on the next write** (which re-arms and gates again). Minor.
- **Trivial-skip is bypassable-by-retry.** Any "trivial change may proceed" escape
  is by construction bypassable; this is a **forcing function to make Claude judge
  each edit**, not a hard wall (as consequential change 1 records).
- **Per-agent state accumulates.** Entries keyed by the unique `agent_id`
  accumulate over a long session. Harmless; the hook may prune stale entries, or
  the state may simply be ephemeral (a fresh temp dir per boot). Minor.
- **Path hints are heuristic** and may misfire on ambiguous files; Claude decides
  regardless.

### Rejected approach: soft non-blocking reminder (prior design for this spec)

An earlier revision of this spec proposed making `code-writer-gate`
**non-blocking**: `permissionDecision:"allow"` on every write with a PreToolUse
`additionalContext` routing reminder, never `exit 2`. The appeal was that a pure
reminder has nothing to "escape," so it cannot induce the classifier's
tunneling/forging dynamic at all.

It was **dropped** because Claude Code docs (verified) state a PreToolUse
`additionalContext` is inserted "next to the tool result" and read "on the next
model request" — meaning the **triggering write executes first**, and the reminder
can only steer *subsequent* edits, never the one that fired it. A soft gate
therefore **cannot intercept the very edit it fires on**: it degrades from a gate
to advice about the *next* write, losing the per-edit routing judgment that is the
whole point. The blocking toggle keeps that per-edit interception (the write is
held until Claude judges and retries) while still avoiding an *infinite* loop, at
the accepted cost of the classifier-retry risk that Task 1 must clear. The soft
design's own load-bearing uncertainty (whether the injected context influences
anything at all) was *more* uncertain than the toggle's, and even in the best case
it could not gate the first edit — so the toggle wins.

## Plan

All paths are under `/private/etc/nix-darwin/modules/programs/claude-code/`
unless noted. The revised hook keeps the existing hook skeleton: `set -euo
pipefail`, read stdin into `input`, resolve `jq` tolerantly, parse fields with
`.field // empty` (`code-writer-gate:5-16`, `plan-verifier-gate:6-14`). The
blocking output path is **unchanged from today's gate** — `cat >&2` + `exit 2` for
a block, `exit 0` for an allow (`code-writer-gate:29-36`). State handling mirrors
`plan-verifier-gate:16-25` (a per-key file under `~/.claude/<gate>/`, created and
removed by the hook). Comment header follows `config/skills/comments` (dashed-rule
section labels, why-not-what, concise).

### 1. Task 1 — the gating feasibility probe (throwaway), classifier-retry risk first

Before touching the real hook, prove the mechanism empirically, mirroring the
earlier gate probes (log to a file). Order the checks by risk — the classifier
question first, because it alone can kill the design.

**Probe registration.** Hooks here are Nix-managed and merged at activation
(`claude-code.nix:263-271`), but the probe is a throwaway that must not go through
a gated `nr`/`nrr` rebuild. Because the activation merge is purely *additive*, the
sanctioned throwaway path is a **temporary manual `jq` insert** of the probe hook
into `~/.claude/settings.json` under the PreToolUse `Write|Edit` matcher (a later
rebuild re-asserts the flake-owned set cleanly). **Remove the probe hook
afterward** (jq-delete it and its script). Run **no** `nr`/`nrr`.

The probe hook on `Write|Edit`, in a fresh/rebuilt session, must establish, in
order:

1. **[TOP RISK] The block→retry cycle stays clear of the safety classifier.** Have
   the probe **`exit 2`-block** a write (with a short stderr like the real gate's),
   then observe whether Claude **re-issues the same `Write` and it proceeds
   smoothly**, or whether the retry is **flagged/denied as bypass/tunneling**.
   Test it on *repeated* edits (block→retry→block→retry across several writes),
   since the real gate does this on every edit. **If the retry is flagged, STOP
   and revisit with the user** — the toggle may thrash exactly like the marker
   design. This is THE make-or-break unknown.
2. **Payload fields for keying.** Log the full payload and confirm it carries
   `agent_id` (to key per-agent state) and `agent_type`, and confirm what
   identifies the **main session** (expected: `session_id`, and `agent_id`
   absent/empty).
3. **A retry re-fires `PreToolUse`.** Confirm the retried write triggers the hook a
   **second** time with the same fields (so the toggle sees it as a distinct call),
   and confirm `exit 2` blocks the `PreToolUse` write with the stderr fed back to
   the agent (today's gate already relies on this — `code-writer-gate:29-36`). Note
   the retry is a **fresh, model-driven re-decision**: the model reads the blocked
   stderr and *chooses* to re-issue the `Write`, which re-fires `PreToolUse` — it is
   not a transparent/automatic tool replay. That model-driven re-issue is exactly
   the surface the safety classifier judges, so the probe must exercise the real
   model retry (not a hypothetical replay) to prove check 1 holds.
4. **The hook can read/write its harness-side state file.** It runs unsandboxed,
   but verify the chosen state dir (e.g. `~/.claude/code-writer-gate/`, alongside
   `plan-verifier-gate`'s) is writable from the hook context — create, read, and
   delete a probe file.

**Decision gate:** if the retry proceeds smoothly and the payload carries the
keying fields → proceed to build the real hook. If the retry is flagged as
bypass/tunneling → **stop and revisit with the user**; the toggle design may be
infeasible.

### 2. Revise the hook — `config/hooks/code-writer-gate`

Rewrite the existing file (keep the filename so registration is unchanged) to the
toggle gate:

- Parse `agent_type`, `agent_id`, `session_id`, and `file_path` from `input`
  (`.agent_type // empty`, `.agent_id // empty`, `.session_id // empty`,
  `.tool_input.file_path // empty`), tolerating `jq` absent exactly as now
  (`code-writer-gate:9-16`).
- **Exemptions FIRST — allow silently, `exit 0`, before any toggle access.** One
  `case "$file_path"` with the `*..*` reject arm **first** (guarding every
  exemption below it against traversal), then:
  - `"$HOME"/.claude/*` (preserve `code-writer-gate:22-27` in spirit).
  - `/private/tmp/claude-*` and `/tmp/claude-*` — leading-anchored only, never a
    floating `*claude-*` (which would swallow this repo's `.../claude-code/...`
    paths).
  These arms `exit 0` immediately so the toggle is never touched for an exempt
  write.
- **Compute the state key:** `key = agent_id` if non-empty, else `session_id` if
  non-empty, else `unknown` (mirror `plan-verifier-gate:14`). State file:
  `"$HOME/.claude/code-writer-gate/$key.disarmed"` — its **presence** means
  disarmed, its **absence** means armed (so the file exists only while disarmed).
  `mkdir -p` the dir on first use, as `plan-verifier-gate:25` does.
- **Toggle logic** (default state = armed, so an unseen key is armed):
  - **Armed** (the `.disarmed` file is **absent** — including an unseen key, which
    has no file) → **disarm** (`touch` the file) and **BLOCK**: `cat >&2` the
    agent-aware message and `exit 2`.
  - **Disarmed** (the `.disarmed` file is **present** for a seen key) → **re-arm**
    (`rm -f` the file) and **ALLOW** (`exit 0`).
  This single polarity — *absent* = armed = block-and-create, *present* = disarmed
  = allow-and-remove — makes the unseen key (no file) default to a block, with no
  separate "unseen" case to special-case. State the polarity in a one-line
  comment. It yields: block on the first/odd write, allow on the retry/even write.
- **Agent-aware BLOCK message** (only reached on the armed→block branch):
  - `agent_type` empty → the main-session message (Spec), retry-is-sanctioned
    framing.
  - `agent_type` one of `code-writer|doc-writer|spec-writer|test-writer` → the
    writer-subagent message, interpolating `agent_type`.
  - `agent_type` any other subagent → the same writer-subagent message is
    serviceable ("are you the right writer for this file"); keep it **one code
    path**, not a growing table.
  - Optionally append the path-based hint (Spec) computed from `file_path`.
- Because the message interpolates values (`agent_type`, hint), build it with a
  plain heredoc / `printf` to stderr (no JSON needed — a `exit 2` block feeds
  stderr back verbatim, exactly as today's gate does at `code-writer-gate:29-36`;
  no `jq`-built JSON is required on the block path).

Keep the file short and single-path.

### 3. Nix registration — `claude-code.nix` (no change needed)

`code-writer-gate` is already registered under the PreToolUse
`"Write|Edit|NotebookEdit"` matcher (`claude-code.nix:89-92`) via the `cmd`
helper, and `readHooks` (`claude-code.nix:39-42`) re-inlines the file's new
contents automatically. **No registration edit is required** — the matcher and
wiring stay as-is.

**Additive-merge caveat (only matters for removal).** The activation merge is
`jq '. * $policy'` (`claude-code.nix:263-271`), purely additive into the live
`~/.claude/settings.json`. Rewriting the hook's *contents* propagates on the next
rebuild (the file is re-materialized from its text), so no manual step is needed
here. The caveat only bites if a hook is ever **removed** from the Nix config —
then a rebuild won't unregister it and a manual `jq`-delete from
`~/.claude/settings.json` is required. Recorded, not actioned.

### 4. Reword the prose that asserts a hard block (config change — task, not now)

Two files assert an absolute block and become inaccurate under the toggle model.
Editing them is a Claude-config change:

- **`config/CLAUDE.md` §7** — replace "a `PreToolUse` hook blocks direct
  main-session file writes, so every change — even a one-line edit — must go
  through a subagent" with toggle-model wording: a PreToolUse hook that **blocks
  each write once for a routing judgment**, satisfied by delegating to the right
  writer (`code-writer` / `doc-writer` / `spec-writer` / `test-writer`) or — for a
  very small, obvious change — by simply **retrying** the edit. Keep the rest of §7
  (delegate non-trivial work; pass full context; relay questions) intact — the
  delegation *norm* survives; only the *absolute-block* claim changes.
- **`config/hooks/code-writer-plan-reminder`** — reword its header (~line 3) and
  its `additionalContext` (line 9) to still steer plan implementation to
  `code-writer`, but drop the "Direct writes are blocked by a PreToolUse hook … so
  delegation is mandatory" assertion; the gate now blocks each write once for a
  judgment rather than absolutely.

Both edits are project/config files and go through the normal delegated flow when
implemented; they are **not** done in this spec.

### 5. Testing

- **Unit-test the toggle** by piping synthetic `PreToolUse` payloads on stdin and
  asserting **both** the exit code / stderr **and the state-file transition** each
  call causes. Use a temporary `HOME` (or a temporary `~/.claude/code-writer-gate`)
  per test so state is isolated, and inspect the marker file before/after:
  - **Armed → block + disarm:** first call for a fresh key (project path,
    `agent_type` empty) → `exit 2`, main-session stderr present, and the state
    flips to disarmed. Assert the exact transition.
  - **Disarmed → allow + re-arm:** the immediate second call for the **same** key
    → `exit 0`, no block, and the state flips back to armed. (This is the retry
    that proves no infinite loop.)
  - **Re-arm gates the next write:** a third call for the same key → `exit 2`
    again (block/allow alternation holds across edits).
  - **Exempt paths → allow + no toggle change:** `file_path` under
    `$HOME/.claude/...`, under `/private/tmp/claude-.../scratchpad`, and under
    `/tmp/claude-...` → `exit 0` with **the state file untouched** (assert the
    marker's presence/absence is identical before and after — an exempt write must
    not consume the armed slot).
  - **Traversal guard:** `file_path` containing `..` under `~/.claude` **or** under
    the scratchpad prefix → **not** exempt (single guard covers both) → goes
    through the toggle (block-or-allow per current state).
  - **Substring guard:** a project path containing `claude-` (e.g.
    `.../claude-code/config/hooks/x`) → **not** exempt (anchored glob) → toggled.
  - **Agent-aware message per `agent_type`:** on the block branch, `agent_type`
    empty → main-session text; each of the four writers → writer-subagent text
    naming that `agent_type`; a non-writer subagent → the serviceable
    writer-subagent text. Assert the right message on the `exit 2` stderr.
  - **Keying:** a payload with `agent_id` set keys on `agent_id`; with `agent_id`
    empty but `session_id` set, keys on `session_id`; with both empty, keys on
    `unknown`. Assert two different keys keep **independent** armed state (blocking
    one does not disarm the other).
  - **Path-hint cases:** `specs/x.md` → hint `spec-writer`; a docs path →
    `doc-writer`; a test path → `test-writer`; a `.nix` module → `code-writer`.
  - **`jq` shadowed out of `PATH`** → still runs (degraded: no interpolation, a
    static block message) and still toggles/blocks correctly, mirroring the gates'
    fail-tolerant `command -v jq || true` stance.
- **Live probe from Task 1** covers what unit tests cannot: the classifier-retry
  behavior (does re-issuing the write after `exit 2` proceed smoothly), that a
  retry re-fires `PreToolUse`, and the real payload's field names. The unit tests
  prove *state-machine correctness*; the probe proves *runtime feasibility*.

### 6. Validation (dry-build; don't switch)

Per `CLAUDE.md` "Validating changes" and MEMORY (new files must be staged; nix
eval needs the sandbox disabled): `git add` the revised hook (and the reworded
`CLAUDE.md`/`code-writer-plan-reminder` when those tasks land), then with
`dangerouslyDisableSandbox: true`:

- `nix flake check`
- `nix build .#darwinConfigurations.cedar.system --no-link`

Confirm both succeed. Do **not** `switch` or run `nr`/`nrr`.

## Tasks

1. **Feasibility probe (gating, throwaway).** Register a temporary PreToolUse
   `Write|Edit` hook that logs the full payload and `exit 2`-blocks; in a
   fresh/rebuilt session confirm, in risk order: (a) **[TOP RISK]** re-issuing the
   same write after the block **proceeds smoothly** and is **not** flagged as
   bypass/tunneling, across several repeated block→retry cycles; (b) the payload
   carries `agent_id` and `agent_type`, and `session_id` identifies the main
   session; (c) a retry **re-fires** `PreToolUse` and `exit 2` blocks with stderr
   fed back; (d) the hook can create/read/delete a state file under
   `~/.claude/code-writer-gate/`. **If the retry is flagged, STOP and revisit with
   the user** — the toggle design may be infeasible. Remove the probe hook after.
2. **Revise `config/hooks/code-writer-gate`** to the per-agent toggle gate
   (Plan §2): parse `agent_type` + `agent_id` + `session_id` + `file_path`; exempt
   `~/.claude` (with `..` guard) and the scratchpad **without touching the toggle**;
   else compute the per-agent key, block-and-disarm when armed (agent-aware `exit 2`
   message + optional path hint), allow-and-re-arm when disarmed; keep the
   jq-tolerance pattern and the `exit 2`/`exit 0` output path unchanged.
3. **Unit-test the toggle** (Plan §5): assert the armed→block+disarm,
   disarmed→allow+re-arm, and re-arm-gates-next transitions; exempt-paths
   allow **and leave the state file untouched**; independent per-key state;
   agent-aware message per `agent_type`; hints correct; `jq`-absent degrades
   gracefully. Drive it with synthetic payloads and inspect the state file.
4. **Reword the hard-block prose** (Plan §4): `config/CLAUDE.md` §7 and
   `config/hooks/code-writer-plan-reminder` to describe the toggle-gate model
   (blocks each write once for a judgment; satisfiable by delegating or, for a
   trivial change, by retrying).
5. **Validate** (Plan §6): `git add`, then sandbox-disabled `nix flake check` and
   the cedar darwin dry-build. Surface any failure; do **not** `switch`.

Registration in `claude-code.nix` is unchanged (Plan §3) — the matcher already
covers `code-writer-gate` and `readHooks` re-inlines the new contents. Task 1
gates all the rest; Tasks 2–3 (revise + test the hook) may land as one commit;
Task 4 is a separate prose/config commit; Task 5 proves the module still
evaluates.
