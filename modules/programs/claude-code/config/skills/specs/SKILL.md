---
name: specs
description: How a project organizes and uses specs — short-lived, pre-implementation working documents that capture an architectural decision plus its plan and tasks. Covers the top-level specs/ directory (one short-named markdown file per spec, or a subfolder for a large spec with sub-specs), the Spec/Plan/Tasks sections each file holds, and the transient lifecycle (write → implement → document → delete) in which a spec's durable rationale graduates into the Diátaxis docs and the spec itself is then removed. Use when writing or organizing specs, deciding where a spec lives or what goes in it, or understanding why a spec is deleted after a feature ships; see [[diataxis]].
---

# Specs

**A project's specs live in a top-level `specs/` directory — one markdown file
per spec, named for what it specs, no number prefixes.** A spec is a *transient
working document*: it captures a decision and a plan before the code exists, and
it is deleted once that code is built and documented. The code and the docs are
the lasting record; the spec is scaffolding.

## Layout

```
specs/
├── parse-config-flags.md        # one spec = one short-named file
├── offline-sync.md
└── billing/                     # a large spec → a subfolder of sub-specs
    ├── billing.md               # the overview
    ├── invoicing.md
    └── dunning.md
```

- **Short, descriptive, kebab-case names.** Name the file for the change, not a
  number — `offline-sync.md`, not `0003-sync.md`. A stable name is the handle.
- **Subfolder for a large spec.** When one spec splits into smaller sub-specs,
  give it a folder holding an overview file plus the sub-specs.

## File anatomy — three sections

Every spec file has the same three sections:

- **`## Spec`** — *what and why.* The change, and the architectural decision
  behind it: the option chosen, the trade-offs, and the growth/swap path (see
  below).
- **`## Plan`** — *how.* The files, types, and data flow; any new dependency or
  pattern, flagged for approval.
- **`## Tasks`** — *the breakdown.* Ordered, self-contained steps — each one a
  commit point.

## Lifecycle — specs are transient

A spec is not a permanent source of truth; it is consumed:

1. **Write** — [[spec-writer]] reasons about the architecture and writes the spec.
2. **Implement** — [[code-writer]] finds the applicable spec (via [[spec-reader]])
   and builds it.
3. **Document** — the durable *why* graduates into the project's Diátaxis docs
   (an explanation page or ADR — see [[diataxis]]).
4. **Delete** — the consumed spec is removed; a whole file when fully implemented,
   just the consumed sections when partial.

So **match a spec's durability to the change it describes**: it exists to get the
work built and its rationale recorded, then it goes. Code answers *what the system
does*; the docs answer *why*; a stale spec that survives only drifts and lies.

## Architectural philosophy — design for growth

Specs should **prioritize designs that allow growth beyond today's expected
capacity.** Prefer the simplest solution that does the job *behind a clean seam*,
so a better-scaling solution can be swapped in later — over a complex,
scale-everything design built upfront. Accept a choice that doesn't scale far now
when it is cleanly replaceable; reject premature scaling complexity. This is the
"simple and elegant above all" rule applied to architecture: the cheapest design
that keeps the future open wins.

## Who does what

- **[[spec-writer]]** — writes and verifies specs: reasons about the best
  architectural trade-offs for this project, researches options on the web,
  honors the project's existing architectural standards, and surfaces every real
  fork to the user instead of guessing.
- **[[spec-reader]]** — reads the `specs/` directory to report what is already
  specced, quoting the relevant passages.
- **[[code-writer]]** — consumes an applicable spec, then retires it after the
  documentation step.

## Related skills

- [[diataxis]] — where a spec's durable rationale graduates to; specs are the
  transient pre-implementation counterpart to those lasting docs.
- [[spec-writer]] — the agent that writes and verifies specs.
- [[spec-reader]] — the agent that reads them.
- [[code-writer]] — the agent that implements a spec and retires it.
