---
name: diataxis
description: The Diátaxis architecture for organizing technical documentation — four distinct types (tutorials for learning, how-to guides for tasks, reference for information, explanation for understanding) arranged on two axes (action vs cognition, acquisition vs application), the discipline of keeping them separate, and the docs-root page that explains both this system and the project's own documentation setup. Use when writing, structuring, or reviewing documentation; deciding what kind of doc a page should be; untangling docs that mix tutorial/how-to/reference/explanation; laying out a docs site's top-level sections; or writing a docs tree's root/landing page.
---

# Diátaxis: a documentation architecture

There are **four distinct kinds of documentation**, each serving a different
need. Keep them separate — most bad docs are bad because they blur these
together (e.g. a tutorial that keeps detouring into reference). Separate them and
each one gets better. Diátaxis (Greek: *dia* "across" + *taxis* "arrangement")
is a compass for deciding which kind you're writing.

## The four types

- **Tutorial** — *learning-oriented.* A lesson that takes a beginner through
  doing something end-to-end. Goal: the reader gains confidence and skill. You
  decide what they do; you're the teacher.
- **How-to guide** — *task-oriented.* A recipe to accomplish a specific goal the
  reader already has ("how to deploy to staging"). Assumes competence; just the
  steps, no teaching.
- **Reference** — *information-oriented.* Dry, complete, accurate description of
  the machinery: APIs, config options, flags. Mirrors the structure of the
  thing. Describes; does not explain.
- **Explanation** — *understanding-oriented.* Discursive background: *why* it
  works this way, design rationale, alternatives, trade-offs. Read to understand,
  not to do.

## The two axes that generate them

|                              | **Action** (doing) | **Cognition** (knowing) |
| ---------------------------- | ------------------ | ----------------------- |
| **Acquisition** (studying)   | Tutorial           | Explanation             |
| **Application** (working)    | How-to guide       | Reference               |

- Vertical: is the reader **learning** (acquiring skill) or **working**
  (applying it)?
- Horizontal: is the content **practical steps** or **theoretical knowledge**?

## The confusions to avoid

- **Tutorial vs how-to** — a tutorial serves a learner who doesn't yet know what
  to ask; a how-to serves a doer with a specific goal. Mixing them serves
  neither.
- **Reference vs explanation** — reference says what the thing *is* (factual,
  complete); explanation says *why* it is (discursive). Don't smuggle rationale
  into reference or facts into explanation.

## How to apply it

- It's a **compass, not a rigid map** — you don't redesign all docs top-down.
- For any page, ask **"which of the four is this?"** and split out the parts that
  belong in a different quadrant.
- **One page, one type.** Give each quadrant its own section/folder
  (`tutorials/`, `how-to/`, `reference/`, `explanation/`) so readers navigate by
  need. For organizing *within* a quadrant (earned subfolders) and the working
  discipline around docs — docs-first reading and capturing gaps — see
  [[skill:documentation]].

## The docs root explains the system

The root page of the docs tree (`docs/README.md`, `index.md`, or the site's
landing page) always carries two things, so a reader — or a future agent — can
navigate and extend the docs without prior knowledge:

1. **How Diátaxis works** — a short orientation: the four types, the need each
   serves, and where each lives in this tree; link to https://diataxis.fr for
   the full theory.
2. **This project's documentation setup** — whatever is specific to the
   project: the generator/tooling and how to build or preview the docs, the
   folder layout, naming conventions, and any local carve-outs.

Write this page first when creating a docs tree; when working in docs whose
root lacks either part, add the missing part.

## Reference

Official site: https://diataxis.fr

## Related skills

- [[skill:documentation]] — the working discipline: docs-first reading, gap
  capture, and earned subfolders within a quadrant.
- [[agent:doc-writer]] / [[agent:doc-reader]] / [[agent:doc-reviewer]] — the agents that write,
  read, and review docs in this architecture.
- [[skill:specs]] — the transient pre-implementation working documents whose durable
  rationale graduates into these docs once a feature ships.
- **Documentation tooling** — identify the current project's documentation system
  directly; its generator and publishing workflow vary by project.
