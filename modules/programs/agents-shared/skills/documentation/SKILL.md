---
name: documentation
description: The working discipline for project documentation — docs are the source of truth for high-level flow (consult them before the code; code is for low-level detail only), needing code to learn a high-level flow is a docs defect to capture, and the two gap types (reference gap and how-to gap) have a capture flow — note gaps when hit, surface them at the task's end, ask the user before updating, dispatch doc-writer on yes. Also covers organizing a docs section into earned subfolders of arbitrary depth. Architecture-agnostic, with Diátaxis as the default via [[skill:diataxis]]. Use when debugging, investigating a codebase, or about to read code to understand how something works at a high level; when you've just discovered a generally applicable procedure worth writing down; and when writing, organizing, or placing documentation pages — deciding where a page goes or whether a subfolder is warranted.
---

# The documentation discipline

**Docs are the source of truth for high-level flow.** For any question about how
a system works at a high level — its flows, its architecture, how to perform a
task with it — consult the project's documentation *before* the code. Code is for
low-level detail only. Needing the code to learn a high-level flow means the
documentation failed; that is a defect to be captured, not shrugged off.

## Gate: does a docs system exist?

The discipline applies where a real documentation system exists — the same test
the doc agents use: a structured docs tree (a `docs/` directory with quadrant
folders or several pages) or a docs generator config, not a lone README. Where
none exists, note that and move on — never invent a docs system unprompted.

## The two gap types

- **Reference gap** — you had to read code to learn a high-level flow or
  structure. The reference section should have covered it.
- **How-to gap** — while debugging or working you discovered a generally
  applicable procedure (e.g. how to exercise a behavior across the network, how
  to access and modify the database, how to test something). The how-to section
  should have covered it.

## The capture flow

1. **Note each gap the moment you hit it** — what you needed, where you ended up
   finding it, and which section should have carried it.
2. **At the natural end of the task, surface the gaps to the user and ask
   whether to update the docs.** Never update silently, never drop the gaps
   silently.
3. **On yes, dispatch [[agent:doc-writer]]** with the gap list — it places pages
   per the project's architecture and hands off to doc-reviewer.

Subagents that hit gaps can't ask the user — they report gaps in their findings
so the dispatcher can ask.

## Organizing sections: earned subfolders, arbitrary depth

Within a docs section, group pages into subfolders along logical seams — by
action type in how-to (canonical: `how-to/debugging/`), by subsystem in
reference. Nesting may go arbitrarily deep, but **every level must be earned**:

- Create a folder only when several pages (≈3+) share a theme.
- Never a single-file folder; never an empty folder made in anticipation.
- Prefer flat until grouping genuinely aids navigation — be wary of
  subsectioning too much.
- Keep the docs root's index in step with any reorganization.

## Default architecture

Unless the project already uses a different documentation system, the default is
Diátaxis — see [[skill:diataxis]] for the four kinds and their separation. The
discipline above applies whatever the architecture; only the section names
change.

## Related skills

- [[skill:diataxis]] — the default documentation architecture: the four kinds and keeping them separate
- [[agent:doc-reader]] — reads what the docs already say about a topic
- [[agent:doc-writer]] — writes the pages that close a captured gap
- [[agent:doc-reviewer]] — proves coverage, accuracy, and placement
