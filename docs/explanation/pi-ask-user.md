# Why ask-user follows the session branch

The `ask-user` extension lets the agent ask one question and reopen it after a
clarification. It must keep that reopen correct when the user moves through
the session tree, and it must stay out of the editor's up-arrow history.

These behaviors stay fixed:

- One question per `ask_user` call, with 2 to 12 options.
- Markdown option previews, scrolled with `Ctrl+Alt+J` and `Ctrl+Alt+K`, with
  the `┃` thumb on the `│` track.
- The free-form row and the clarifying-question row.
- The reopen after Pi settles. `agent_settled` stays the reopen event, because
  Pi fires it after retries, compaction, queued work, and continuations.
- Escape inside an input row returns to the option menu.

The extension adopts a robustness pattern only when it prevents a failure that
can happen in this code today.

## Why the prompt history filled with answers

The history had two causes.

The first cause was local. The extension sent each reopened answer with
`pi.sendUserMessage`, which stores a message with role `user`. The user never
typed that message. Pi copies every user message into the editor's history
when it rebuilds the transcript. A rebuild happens on startup, resume, a
session switch, `/tree`, and an extension's `ctx.navigateTree`. A live send
does not reach the history, so the bug appeared only after a rebuild and
looked intermittent.

The second cause sits in Pi itself. `Editor.addToHistory` drops only a
consecutive duplicate, and the editor never clears its history. Each rebuild
therefore pushes the branch's user messages again. No simple local workaround
exists:

- `Editor.history` is private, so an override cannot remove earlier entries.
- A custom editor component starts with an empty history.
- The workflows extension already replaces the editor while it runs, so a
  second editor override would conflict.

This cause stays an upstream TODO in `TODO.md`.

## Why the answer is a custom message

Pi stores a custom message as a `custom_message` entry. The rebuild adds only
user messages to the history, so a custom message never reaches it. Pi still
converts the custom message to user-role text for the model, so the agent reads
the answer. A triggered custom message waits for the `agent_settled` handlers,
as a prompt does, so `/tune` still waits for the follow-up run. The `/tune`
extension already sends its turns this way.

A user message would recreate the bug. A tool result cannot carry the answer
either. The tool call has already ended when Pi settles, so a tool result would
need another call from the model. That call would replace the automatic reopen.

Pi's default rendering of a custom message is a box with a bold
`[ask-user-answer]` label. A message renderer replaces it with one line in the
wording of the tool's own result.

## Why the pending question comes from the branch

The extension once kept the pending question in memory. `/tree` keeps the same
extension instance, so that memory survived a jump to another branch. After
`/tree` to an entry before a clarification, the next settle reopened the
question from the abandoned branch. A `/tune` rewind after an aborted answer
also kept the question, and the user's next, unrelated run reopened it.

Pi's extension guide prescribes the fix: reconstruct branch-sensitive state
from `ctx.sessionManager.getBranch()`. At each `agent_settled`, the extension
walks the branch and keeps the latest of three markers:

- the `details` of an `ask_user` tool result
- the `details` of an `ask-user-answer` custom message
- the `data` of an `ask-user` custom entry

The question is pending only when the latest marker is a clarification. An
`ask_user` result without `details.status`, such as an error result, is not a
marker. The branch is complete at `agent_settled`, because Pi saves each
message and flushes pending custom messages before it emits the event.

Sessions saved before the fix store their reopened answers as user messages.
The rule therefore reads two legacy markers. A user message that starts with
`My answer to the pending question "` clears the question. A user message that
starts with `I need another clarification before answering "` keeps it
pending. Without them, a resumed legacy session would reopen an answered
question.

### Which commands keep the extension instance

Pi gives each extension a fresh instance on `/fork`, `/clone`, `/new`,
`/resume`, `pi -c`, and `/reload`. Each of these commands starts with empty
in-memory state. `/tree`, the extension call `ctx.navigateTree`, and
compaction keep the same instance and its memory. Only the branch is correct on
every path.

### Why a small in-memory guard remains

While the reopened dialog is open, Pi defers each new run. Another extension can
queue a triggered message ahead of the answer, as pi-subagents does for
background notices. That run settles before Pi saves the answer. The latest
marker is still the clarification, so the dialog would reopen and the answer
would go out twice.

The guard remembers the marker that the extension reopened and skips the reopen
while that marker stays the latest. It clears at the first settle with a
different latest marker. It also clears on `session_tree`, because `/tree`
keeps the instance. A session replacement starts a fresh instance with no
guard.

A synchronous entry written at reopen time would also stop the double reopen.
That entry would become the latest marker, so `/tree` to the answer could no
longer make the question pending again.

### Why the simpler reset fails

The rejected alternative keeps the in-memory pending question and resets it on
`session_tree`. That change is one line. It forgets the question after `/tree`
back to the clarification and after every session replacement.

### Why going back to an answer reopens the question

`/tree` to an `ask-user-answer` entry makes the question pending again and puts
the old answer into the editor. The user chose this behavior. Going back to an
answer then works like going back to a user message: the user can answer again.

## Why an early-ending answer run drops the question

After an abort during the agent's answer, the old extension reopened the dialog,
and the user had to press Escape again. A `/tree`, `/fork`, or `/new` during the
answer also reopened the dialog inside Pi's abort path. An abort now drops the
question.

A provider error with no retry left and an extension that cancels an
auto-compaction also drop the question, although the user did not abort.
Extensions do not receive Pi's `auto_retry_end` event, and
`session_compact_failed` does not tell a user's cancel from an extension's. In
every one of these cases the agent never finished its answer, so a reopen would
ask without that answer.

## Why the tool is model-only

Codemode is Pi's tool that runs a model-written script. A script can call any
tool with the default `direct` exposure. A script that called `ask_user` would
receive the clarification text, and the model would never see it. A nested call
also writes no transcript entry, so the branch rule could not see its
clarification. Pi's extension guide recommends `model-only` for tools that ask
the user.

## Why the extension normalizes line terminators

pi-tui breaks a line at every line terminator, including a bare carriage
return. A model can emit a bare `\r` inside a label, and the dialog then renders
that option as stacked rows. The extension removes `\r` before schema
validation, so the duplicate-label check sees the normalized labels. It keeps
`\n`, because the workflow question uses `\n\n` on purpose.

## Rejected patterns

rpiv-ask-user-question carries several patterns that this extension leaves out:

- **Custom tool-row renderers.** Pi's default tool rendering already shows the
  outcome text, for example `User selected option 2: SQLite`.
- **Removing the tool when no UI exists.** In print and JSON modes, the model
  spends one call to learn that it must ask in normal text. That cost does not
  justify a new hook.
- **A separate pure key router.** The dialog reducer is already pure, and the
  audit found no routing bug.
- **Reserved labels.** RPC mode numbers its choices, and the TUI selects by
  index, so a label cannot collide with a row.
- **A shared import seam for workflows.** The type-only import of the dialog
  event costs nothing at runtime. A missing export already fails the workflows
  check.
- **An event bus, an answer channel, lazy loading, translations, and a
  configuration file.** No consumer here needs them.

## Growth seam and non-goals

Multiple questions per call and multi-select would extend the tool's parameters
and the dialog's events. The branch rule reads only its markers. A richer
answer shape carries over unchanged through the three current markers.

Both features stay non-goals, because no reported failure needs them.
