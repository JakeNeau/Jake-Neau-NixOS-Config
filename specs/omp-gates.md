# omp gate hooks

Reimplement Claude Code's enforcement hooks as an oh-my-pi (omp) TypeScript
extension in `modules/programs/oh-my-pi/`. The omp migration
(`specs/omp-migration/`, since retired) dropped Claude Code's gate hooks in
favor of RULES.md prose; this spec is the prepared enforcement equivalent.

**Status: spec only — implement when RULES.md discipline proves too soft in
live omp use.** The design was settled and validated ahead of need; the
implementation trigger is tracked in `TODO.md`.

## Spec

### What is being replicated

The Claude Code originals live in `modules/programs/claude-code/config/hooks/`:

1. `plan-verifier-gate` — PreToolUse on ExitPlanMode; blocks presenting a plan
   until plan-verifier has vetted it (marker-file protocol keyed by session id).
2. `code-writer-gate` — PreToolUse on Write/Edit/NotebookEdit; blocks direct
   main-session writes, forcing delegation to subagents (CLAUDE.md §7); exempts
   `~/.claude` paths.
3. `code-review-writer-gate` — SubagentStop on code-writer; a run that edited
   files cannot stop without having dispatched code-reviewer; surrenders after
   one block via `stop_hook_active`.
4. `code-review-comments-gate` — SubagentStop on code-reviewer; cannot stop
   without having dispatched comment-style-enforcer; same surrender.
5. `code-writer-plan-reminder` + `comment-style-enforcer-reminder` — PostToolUse
   on ExitPlanMode; inject reminders (implement via code-writer, not direct
   edits; run comment-style-enforcer after all edits, before verification).

### Verified omp API facts

All verified against the pinned omp v16.4.8 source
(github.com/can1357/oh-my-pi, tag v16.4.8, `packages/coding-agent/`). The pin
moves daily — re-verify these at implementation time (see the verification
plan below).

- Extensions are loose `.ts` modules under `~/.omp/agent/extensions/`, imported
  natively by Bun **in the same process** as the agent
  (`src/extensibility/extensions/loader.ts`, "loads TypeScript extension
  modules using native Bun import"). Each default-exports a factory
  `(pi: ExtensionAPI) => void` (`ExtensionFactory` in
  `src/extensibility/extensions/types.ts`). Full Bun/Node access; every handler
  runs under a 30 s timeout (`EXTENSION_HANDLER_TIMEOUT_MS` in `runner.ts`).
- `tool_call` event: pre-execution interception of every tool (built-ins, MCP,
  the `task` tool, subagents' `yield` tool). Handler receives
  `{toolCallId, toolName, input}` plus an `ExtensionContext` (`ctx`); returning
  `{block: true, reason}` blocks the call and the reason surfaces to the model
  as the tool error (`ToolCallEventResult` in
  `src/extensibility/shared-events.ts`; blocking path in
  `src/extensibility/extensions/wrapper.ts`, `ExtensionToolWrapper.execute`).
  The runner is **fail-closed**: a throwing or timed-out `tool_call` handler
  blocks the tool (`runner.ts`, "an unresponsive extension MUST NOT be treated
  as silent consent").
- `tool_result` event: post-execution middleware; can rewrite
  `{content, details, isError}`.
- `session_stop` is a faithful Claude Stop-hook equivalent
  (`decision: "block"`, `stop_hook_active`, capped at 8 continuations) but
  **never fires for subagent sessions** (`agentKind === "sub"` guard in
  `src/session/agent-session.ts`) — there is no SubagentStop.
- Extensions load inside subagent sessions too (parent forwards
  `preloadedExtensionPaths`; factory re-runs per session, `sdk.ts`). Every
  subagent must call a `yield` tool to finish (`requireYieldTool: true` in
  `src/task/executor.ts`).
- Transcript access: `ctx.sessionManager: ReadonlySessionManager`
  (`src/session/session-manager.ts`) — `getEntries()` returns the full session
  journal (messages with tool calls, `mode_change` entries carrying
  `planFilePath`, custom entries).
- No "which agent am I" API inside a child session; `ctx.getSystemPrompt()`
  includes the rendered agent definition text.
- Plan mode exists but has **no plan-approval extension event**; plan approval
  flows through a `resolve` tool invocation with an apply action
  (`#runPlanApprovalResolve` in `src/modes/interactive-mode.ts`), and plan-mode
  transitions are recorded as `mode_change` session entries.
- The `task` tool's input (`TaskParams` in `src/task/types.ts`) names the
  spawned agent type.
- omp config here sets `tools.approvalMode: "always-ask"` (see `configPolicy`
  in `modules/programs/oh-my-pi/oh-my-pi.nix`) — every write/exec tool call
  already prompts the user for approval.

### Architecture

One new extension,
`modules/programs/oh-my-pi/config/extensions/gates.ts`, delivered to
`~/.omp/agent/extensions/gates.ts` via `home.file` in
`modules/programs/oh-my-pi/oh-my-pi.nix`, exactly like the existing
`flow-map.ts`. All gates live in this one module as `api.on("tool_call")` /
`api.on("tool_result")` registrations, sharing two helpers: a transcript
scanner over `ctx.sessionManager.getEntries()` and an agent-identity probe.
The same file loads in the main session and every subagent session; each
handler self-selects by context (mirrors how the CC bash hooks self-filter on
`agent_type`).

### Agent identity markers

Decided over an extension-internal lifecycle-event Map, which would ride omp's
internal untyped `task:subagent:lifecycle` bus channel — rejected as fragile
under the daily-bumped llm-agents pin.

Plant a fixed one-line marker comment (e.g. `<!-- gate-id: code-writer -->`)
in the agent definition files we own:
`modules/programs/oh-my-pi/config/agents/code-writer.md` and
`code-reviewer.md`, each with a short adjacent note explaining the marker is
load-bearing for gates.ts. The identity probe greps `ctx.getSystemPrompt()`
for the markers: specific marker → that agent's yield gate arms; any marker →
session is a subagent (write gate stands down); none → main session.

### Gate 1 — write gate, challenge-then-approval (main session only)

`tool_call` handler on omp's write/edit tools. The first attempt at a given
file is blocked with a steering reason: choose the proper agent for this
change (code-writer for non-trivial work); if a direct main-session write is
genuinely right, justify it to the user first. A retry of the same write is
allowed through — where omp's native `always-ask` approval prompt makes the
user the final arbiter, with the model's justification visible in the
transcript above the prompt. Challenged writes are remembered in module-level
state keyed by file path. Writes under `~/.omp/` are exempt (omp's own
scratch/state, the analogue of CC's `~/.claude` carve-out).

Decided over: a hard block like CC — rejected to keep an escape hatch since
`always-ask` already guards consent; and warn-don't-block — rejected as the
soft discipline that already proved the problem.

### Gate 2 — code-writer yield gate

In a session whose system prompt carries the code-writer marker, a `tool_call`
handler on `yield` scans the child's own transcript: file edits present but no
`task` dispatch of code-reviewer → block yield with a reason directing it to
dispatch code-reviewer, then yield again. Blocks at most once per session
(module/session state — the CC `stop_hook_active` surrender), then permits
the stop.

Mechanism decided over parent-side `task` `tool_result` rewriting — rejected
because the child's context is already gone by then; child-side blocking lets
the subagent fix the omission with full context.

### Gate 3 — code-reviewer yield gate

Same shape as gate 2: block `yield` until a comment-style-enforcer `task`
dispatch appears in the transcript; same one-block surrender.

### Gate 4 — plan-verifier gate, transcript check on resolve

`tool_call` handler on the `resolve` tool's apply action, main session only:
scan the transcript since the current plan-mode stretch began (delimited by
`mode_change` entries) for a `task` dispatch of plan-verifier; absent → block
with instructions to dispatch plan-verifier, present its verdict to the user
alongside the plan, and only then apply.

No marker protocol — decided over replicating CC's marker-file protocol, which
the model could satisfy without truly verifying; here the dispatch itself is
the evidence and cannot be faked.

### Gate 5 — plan-approval reminders

`tool_result` handler on a successful `resolve` apply: inject the two CC
reminder texts as additional context —

- (a) implement via the code-writer subagent, not direct main-session edits
  (which the write gate challenges anyway), handing it full task context since
  it sees none of the conversation;
- (b) after ALL edits and BEFORE any verification, dispatch
  comment-style-enforcer over the changed files — skip only if code-writer did
  the implementation, since it runs the enforcer itself.

### Error handling

omp's runner is fail-closed for `tool_call` handlers; for discipline gates
that's the wrong default (a bug would block every gated tool), so every
handler body wraps in try/catch and fails open (allow) on internal errors —
matching the CC hooks' tolerance of missing jq / unreadable transcripts. The
30 s timeout remains the one residual fail-closed path; handlers are pure
in-memory scans, so it is not a realistic risk.

Residual, accepted risk: identity detection failing (marker missing from a
future agent-file edit) fails open silently — discipline quietly unenforced;
the marker's adjacent explanatory note is the mitigation.

### Verification plan

Nothing is testable on cedar — no omp installed. At implementation time:

1. Re-verify the load-bearing API facts against the then-pinned omp source
   (event names, `yield`/`resolve` tool names and input shapes, `mode_change`
   entry shape, write/edit tool names) — the pin moves daily and any of these
   may have drifted from the 16.4.8 facts above.
2. Typecheck `gates.ts` with bun/tsc.
3. Dry-build an omp home
   (`nix build '.#homeConfigurations."<user>@<host>".activationPackage'
   --no-link`, or eval the drvPath on darwin for Linux homes).
4. Live-verify each gate on an omp machine (redwood/spruce/aspen), the way the
   flow-map extension has a live-verify TODO:
   - direct write challenged once, then approvable on retry;
   - code-writer blocked at yield without a code-reviewer dispatch;
   - code-reviewer blocked at yield without a comment-style-enforcer dispatch;
   - `resolve` apply blocked without a plan-verifier dispatch;
   - reminders appear after plan apply.

## Plan

Deferred — written when the implementation trigger fires (RULES.md discipline
proving too soft in live omp use), since the omp pin moves daily and a
detailed plan written now would rot.

## Tasks

Deferred with the plan, for the same reason.
