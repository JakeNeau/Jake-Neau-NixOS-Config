---
description: Compact the conversation, then immediately run the task or slash command that follows.
argument-hint: <task or /command to run after compacting>
disable-model-invocation: true
---

Do two things in one turn, without pausing for input between them:

1. **Compact first.** Invoke `/compact` (via the SlashCommand tool) to summarize the
   conversation so far, focusing the summary on the context needed for the task below.
2. **Then run the task.** The moment compaction completes, carry out the following in
   the freshly compacted context — if it is itself a slash command, run that command:

$ARGUMENTS

If you cannot trigger `/compact` yourself, do not silently skip it: stop and ask me to
run `/compact` manually, then re-issue the task.
