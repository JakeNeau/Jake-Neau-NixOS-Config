---
name: todo-tracking
description: How this repo tracks TODOs — every outstanding work item goes into the single `TODO.md` markdown checklist at the repo root; there is no other tracking destination (no issue tracker, no per-module lists). Use when recording follow-up work, deferred items, or known issues for this project, or when deciding where a TODO belongs.
---

# Tracking TODOs in this repo

**This project tracks TODOs in exactly one place: `TODO.md` at the repo root.**
There is no second destination — no issue tracker, no per-module TODO lists, no
TODO comments used as tracking. Every item, whatever its topic, goes in that one
file.

## Format

`TODO.md` is a flat markdown checklist under a single `# TODO` heading:

- One `- [ ]` entry per item, wrapped at ~80 columns like the rest of the repo.
- Make each entry self-contained: name the module or file it concerns and what
  "done" looks like, so it can be acted on without today's context (see the
  existing entries for the shape).
- Delete entries when they're done — the file holds only open work.

## Related skills

- [[skill:nix-config]] — the repo layout the entries typically point into
