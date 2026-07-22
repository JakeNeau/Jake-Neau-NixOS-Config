---
description: Conform comments in the current diff or an explicit scope to the shared style
argument-hint: "[scope]"
---

Review and automatically conform comments in this scope:

${ARGUMENTS:-comments added, deleted, or modified in `git diff HEAD`}

First follow the global [[skill:comments]] policy with
`follow_link global:skill:comments`. Identify only comments in the requested
scope, read enough surrounding code and real dependencies to establish intent,
classify each comment, and load each applicable linked category skill once.
When the scope names a file, review every comment in that file.

Work deletion-first. Delete comments that do not earn a line, then shorten,
rewrite, relocate, or split the rest. Enforce the one-line target and two-line
ceiling for ordinary prose. Preserve functional directives and legal or
generated provenance verbatim, and classify adjacent human prose separately.

Change comments only, never code logic. If intent cannot be established, leave
the comment unchanged and report the ambiguity instead of guessing. Finish with
counts of comments deleted, shortened, retained, relocated or split, and
exempted.
