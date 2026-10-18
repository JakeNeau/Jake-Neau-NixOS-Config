## Spec

Add a global Pi extension with the `/tune <draft>` command. The command
runs an interactive exchange with the agent to turn a draft prompt into a tuned
prompt. When the user accepts the proposal, Pi rewinds the session to the point
before `/tune` and submits the tuned prompt there.

### Purpose

A draft prompt often omits context that the agent needs. Examples are project
files, documentation, skills, constraints, and success criteria. `/tune` gathers that
information from the user and the repository before the work starts. The
tuning exchange then leaves the model context, so the resumed conversation
contains only the tuned prompt.

### Scope

- Put the extension source under `modules/programs/pi/extensions/tune/`.
- Install it through `modules/programs/pi/pi.nix` with the existing extension
  pattern.
- Register the `/tune` command and the `propose_prompt` tool.
- Store the tuning instructions in a Markdown file inside the extension
  directory. Do not create a skill, because Pi lists every skill in each
  session's startup context.
- Make the extension global. It works in any project and reads that project's
  instructions and documentation.

### Behavior

1. The user submits `/tune <draft>` in interactive mode.
   - With no draft, Pi shows the usage text and changes nothing.
   - While the agent is busy, Pi shows an error and changes nothing.
   - Outside interactive mode, Pi shows an error and changes nothing.
2. The command records the current session leaf.
3. The command sends the draft with the tuning instructions as a user message
   in the current session. The agent can use the existing conversation as
   context.
4. The agent tunes the prompt according to the instructions:
   - Read the project's agent instructions and documentation before code.
   - Inspect code only as needed.
   - Answer repository questions from evidence instead of asking the user.
   - Ask one material question per turn with `ask_user`.
   - Ask only questions whose answers change the prompt.
   - Do no implementation work.
5. The agent calls `propose_prompt` with the tuned prompt. The prompt must make
   sense without the tuning exchange. It names the relevant files,
   documentation, and skills, and it states the success criteria.
6. After the agent run ends, the command shows the proposal with four choices:
   - **Accept:** Pi navigates to the recorded leaf without a branch summary,
     then submits the tuned prompt as the next user message.
   - **Edit:** The user changes the text in an editor. The command then shows
     the four choices again.
   - **Keep tuning:** The user enters feedback. The command sends it to the
     agent, waits for a new proposal, and shows the choices again.
   - **Cancel:** Pi navigates to the recorded leaf without a branch summary and
     submits nothing.
7. If the agent run ends without a proposal, Pi navigates to the recorded leaf
   without a branch summary and reports that the agent proposed no prompt.

After every ending, the tuning exchange is absent from the model context. It
stays in the session tree as an abandoned branch that `/tree` can open.

`propose_prompt` accepts proposals only during a `/tune` run. Outside a run it
returns an error.

### Platform constraints

`ctx.navigateTree` and `ctx.waitForIdle` exist only on the command context.
Lifecycle and tool handlers must not call them, because those calls can
deadlock the runtime. The `/tune` command handler therefore owns the complete
loop. The `propose_prompt` tool only records the proposal for that handler.

If the session has no entries when `/tune` starts, the recorded position is
the empty session. Navigation must restore that empty state.

### Non-goals

- Integration with the workflow manager or `Shift+Tab` mode selection
- A Claude Code version of the command
- Saving tuned prompts to files
- Changing the model, provider, or thinking level
- Starting a new session

### Acceptance criteria

1. `/tune <draft>` runs the question loop and produces a proposal.
2. After Accept, the tuned prompt is the next user message after the recorded
   leaf. The model context excludes the tuning exchange.
3. Cancel and a run without a proposal restore the model context from before
   `/tune` and submit nothing.
4. The tuning exchange remains visible as a branch in `/tree`.
5. Edit and Keep tuning return to the four choices with the updated proposal.
6. A blank draft, a busy agent, or non-interactive mode changes no session
   state.
7. `propose_prompt` returns an error outside a `/tune` run.
8. `docs/reference/` describes `/tune`, its choices, and its rewind behavior.
9. `nix flake check` and the affected host and home builds pass.

## Plan

### Verified platform facts

Pi 1.3.0 source in the installed bundle sets these constraints:

- `navigateTree(target)` moves the leaf to `target.parentId` when `target` is
  a user message or a `custom_message`. A `parentId` of `null` calls
  `resetLeaf()`. Any other target becomes the leaf itself.
- `_prepareRun` persists a leading system message for the prompt and tool
  loadout before the triggering message. A new session always gets one. A
  later run gets one only after a loadout change. The first tuning user
  message therefore can have a system message as its parent, and a rewind to
  that message cannot restore an empty session.
- `pi.sendUserMessage()` reaches `_startRun` only after asynchronous input
  handlers and an authentication check. An immediate `ctx.waitForIdle()` can
  therefore resolve before the run starts.
- `pi.sendMessage(message)` without `triggerTurn` appends a `custom_message`
  entry synchronously while Pi is idle. With `triggerTurn: true` it calls
  `_startRun` synchronously, and `_startRun` marks the session busy before its
  first `await`.
- `waitForIdle()` also covers runs deferred from `agent_settled`. One example
  is the follow-up that `ask_user` sends after it reopens a pending question.
- In the TUI, the command-context `navigateTree` copies the target's text into
  an empty editor.

### Design decisions

1. **The rewind anchor is a hidden custom message.** The command first appends
   `{ customType: "tune-instructions", content: <instructions>, display: false }`
   without `triggerTurn`. The anchor's `parentId` equals the recorded leaf,
   including `null`. Every ending calls
   `ctx.navigateTree(anchorId, { summarize: false })`. Pi then restores the
   recorded leaf exactly, including the empty session. This approach refines
   spec step 3. The model still receives the instructions and draft as
   user-role content, but as custom messages.
2. **Turns start through custom messages.** The draft is sent as
   `{ customType: "tune-draft", content: "Draft prompt:\n\n<draft>", display: true }`
   with `triggerTurn: true`. Feedback uses the same shape as `tune-feedback`.
   The session is already busy when `pi.sendMessage` returns, so
   `await ctx.waitForIdle()` cannot return early.
3. **The editor text survives the rewind.** `rewind()` saves
   `ctx.ui.getEditorText()` before navigation and restores it with
   `ctx.ui.setEditorText()` afterward. This step stops the anchor's
   instruction text from entering the editor.
4. **`propose_prompt` is a normal direct tool.** It stays always active, like
   `ask_user`. It throws outside an active tuning run. When it succeeds it
   returns `terminate: true`, which ends the run after the proposal. The last
   proposal in a run wins.
5. **The handler owns the loop.** Lifecycle and tool handlers never call
   `navigateTree` or `waitForIdle`. The tool only writes to shared state.
6. **The proposal appears in `ctx.ui.select`.** The title is
   `Tuned prompt\n\n<proposal>`, which is the multi-line title pattern from
   `workflows/ui.ts`. The choices are `Accept`, `Edit`, `Keep tuning`, and
   `Cancel`. Escape counts as `Cancel`.

### Files

- `modules/programs/pi/extensions/tune/core.ts`: all behavior. It must not
  import Pi at run time (type-only imports are allowed), so `node --test` can
  load it.
- `modules/programs/pi/extensions/tune/index.ts`: reads `instructions.md`
  through `new URL("./instructions.md", import.meta.url)` when the command
  runs. Builds the TypeBox schema
  `Type.Object({ prompt: Type.String({ minLength: 1 }) }, { additionalProperties: false })`.
  Calls `registerTune(pi, { loadInstructions, parameters })`.
- `modules/programs/pi/extensions/tune/instructions.md`: the tuning
  instructions.
- `modules/programs/pi/extensions/tune/tests/core.test.ts`: a fake `pi` and a
  fake command context.
- `modules/programs/pi/pi.nix`: the source binding, check, check registration,
  and home entry.
- `docs/reference/pi.md`: a new `Prompt tuning` section.

### `core.ts` symbols

- `TuneState`: holds `active: boolean` and `proposal?: string`. It has these
  methods:
  - `begin()` throws if a run is already active.
  - `clearProposal()` removes the stored proposal.
  - `propose(prompt)` throws
    `propose_prompt is available only during a /tune run.` while `active` is
    false. Otherwise it stores the trimmed prompt.
  - `end()` resets both fields.
- `preflight(args, ctx, state)` returns `{ draft } | { message, level }` and
  has no side effects. It checks these conditions in order:
  1. A blank `args` returns `Usage: /tune <draft prompt>` (`warning`).
  2. `ctx.mode !== "tui"` returns `/tune requires interactive mode.`
     (`error`).
  3. `!ctx.isIdle() || ctx.hasPendingMessages()` returns
     `/tune cannot start while the agent is busy.` (`error`).
  4. `state.active` returns `/tune is already running.` (`error`).
- `registerTune(pi, options)` registers the `tune` command and the
  `propose_prompt` tool. The tool has a one-line description and
  `promptSnippet: "Propose the tuned prompt during /tune"`. It also adds
  `session_start` and `session_shutdown` handlers that call `state.end()`.

### Command data flow

1. Run `preflight`. On failure, call `ctx.ui.notify(message, level)` and
   return.
2. Call `state.begin()` and record `leaf = ctx.sessionManager.getLeafId()`.
3. Append the anchor and read `anchorId = ctx.sessionManager.getLeafId()`.
   Require `ctx.sessionManager.getEntry(anchorId)?.parentId === leaf`.
   Otherwise throw `Pi could not record the /tune rewind point.`
4. Call `state.clearProposal()`. Send the draft message with
   `triggerTurn: true`, then `await ctx.waitForIdle()`.
5. Without a proposal, rewind and notify `The agent proposed no prompt.`
   (`warning`). Then stop.
6. Otherwise loop on the choice:
   - **Accept:** call `rewind()`, then `pi.sendUserMessage(proposal)`.
   - **Edit:** run `ctx.ui.editor("Edit tuned prompt", proposal)`. A nonblank
     result replaces the proposal. A blank or cancelled result keeps it. Then
     show the choices again.
   - **Keep tuning:** run
     `ctx.ui.input("Tuning feedback", "What should change?")`. A blank or
     cancelled result shows the choices again without a run. Otherwise clear
     the proposal, send `tune-feedback` with `triggerTurn: true`, and wait for
     idle. Then continue at step 5.
   - **Cancel or Escape:** call `rewind()` and submit nothing.
7. `rewind()` calls `ctx.navigateTree(anchorId, { summarize: false })` and
   restores the editor text.
   - A `{ cancelled: true }` result throws
     `Pi could not leave the tuning exchange. Open /tree to return.` A
     `session_before_tree` handler can cancel navigation this way.
   - Accept never submits after a failed rewind.
8. `try`, `catch`, and `finally` wrap steps 3 to 7.
   - `catch` makes one rewind attempt if the anchor exists, the rewind has not
     run, and `ctx.isIdle()` is true.
   - `catch` then reports the original error with
     `ctx.ui.notify(..., "error")`.
   - `finally` calls `state.end()`.

The abandoned branch keeps the anchor, draft, feedback, `ask_user` calls, and
proposals, and `/tree` can show it. During tuning the TUI shows the exchange's
tool rows, `ask_user` dialogs, and the choice dialog.

### `instructions.md` content

The file uses controlled English and is written for the agent. It states these
rules:

- The next message is a draft prompt. Tune it and do no implementation work.
- Read the project's agent instructions and documentation before code. Inspect
  code only as needed.
- Answer repository questions from evidence.
- Ask the user only questions whose answers change the prompt. Ask one per
  turn, always with `ask_user`. A question in plain text ends the run without a
  proposal.
- End every run by calling `propose_prompt`, including after feedback.
- The proposal must stand alone without the tuning exchange. It must name the
  relevant files, documentation, and skills (as typed links when the project
  uses them). It must state constraints and success criteria.
- It must also omit any mention of the tuning exchange.

### `pi.nix` changes

- Add `tuneSource = "${extensionSource}/tune";`.
- Add `mkPiTuneCheck`, modeled on `mkPiMinimalTranscriptCheck`:
  1. Copy `tuneSource` and run
     `node --experimental-strip-types --test tune/tests/*.test.ts`.
  2. Pipe `{"type":"get_commands"}` into
     `pi --mode rpc --no-session --offline --no-extensions --extension ./tune/index.ts`.
  3. `grep -q '"name":"tune"'` the output.
- Register `pi-tune = mkPiTuneCheck pkgs;` in `perSystem.checks`.
- Add the `fixedHomeFiles` entry
  `".pi/agent/extensions/tune/index.ts".text = ''export { default } from "${tuneSource}/index.ts";'';`.

### Tests (`tests/core.test.ts`)

The fake context records `notify`, `navigateTree`, `setEditorText`,
`sendMessage`, and `sendUserMessage` calls in order. Its `sessionManager`
assigns entry IDs when `sendMessage` runs without a trigger. A scripted
`waitForIdle` can call the registered tool's `execute`.

1. Each preflight failure (blank draft, `rpc` mode, busy, pending messages,
   active run) sends only the matching notify call, with no messages and no
   navigation.
2. Calling `propose_prompt` outside a run throws the documented error. Inside
   a run, the last call wins and returns `terminate: true`.
3. Accept appends the anchor with `display: false`, and the anchor's parent is
   the recorded leaf. A `null` leaf covers the empty session. Accept calls
   `navigateTree(anchorId, { summarize: false })` before
   `sendUserMessage(proposal)` and restores the editor text.
4. Cancel and Escape each navigate to the anchor and submit nothing.
5. A run without a proposal navigates, warns, and submits nothing. This holds
   for the first run and for a Keep tuning run.
6. Edit with new text shows the choices again with that text. A blank edit
   keeps the old proposal.
7. Keep tuning with feedback sends one `tune-feedback` message with
   `triggerTurn: true` and shows the new proposal. Blank feedback starts no
   run.
8. A cancelled `navigateTree` reports the rewind error, and Accept submits
   nothing.
9. An error from `waitForIdle` triggers one rewind and an error notify, and
   `state.end()` runs.

### Documentation

Add `## Prompt tuning` to `docs/reference/pi.md` after `Selectable questions`.
The section covers these facts:

- `/tune <draft>` is interactive-only and global.
- The usage, busy, and mode errors leave the session unchanged.
- The agent follows the bundled instructions and asks questions through
  `ask_user`.
- The section explains the four choices and the result of each.
- The rewind uses no branch summary, restores the pre-`/tune` model context
  (including an empty session), and leaves the exchange as a `/tree` branch.
- `propose_prompt` errors outside a run.
- The `pi-tune` check runs the unit tests and the RPC registration check.

Instructions live in the extension directory rather than in a skill, which
keeps them out of startup context.

## Tasks

1. Write `tune/tests/core.test.ts` with the cases above. Confirm that the tests
   fail.
2. Implement `tune/core.ts` and `tune/index.ts` until the tests pass.
3. Write `tune/instructions.md` and run `pi-writing-lint` on it.
4. Add `tuneSource`, `mkPiTuneCheck`, the `pi-tune` check, and the home entry
   to `modules/programs/pi/pi.nix`. Run `nix fmt`.
5. Add the `Prompt tuning` section to `docs/reference/pi.md` and run
   `pi-writing-lint` on it.
6. Run `nix flake check` and the `jakeneau` home builds or evaluations for
   every host, following `AGENTS.md`.
7. In a scratch Pi session, check these results by hand:
   - Accept works in an empty session and in a non-empty session.
   - Cancel restores the model context.
   - Edit and Keep tuning return to the choices.
   - `/tree` shows the abandoned branch.
