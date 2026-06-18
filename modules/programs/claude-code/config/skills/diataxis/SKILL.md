---
name: diataxis
description: The Diátaxis architecture for organizing technical documentation — four distinct types (tutorials for learning, how-to guides for tasks, reference for information, explanation for understanding) arranged on two axes (action vs cognition, acquisition vs application), and the discipline of keeping them separate. Use when writing, structuring, or reviewing documentation; deciding what kind of doc a page should be; untangling docs that mix tutorial/how-to/reference/explanation; or laying out a docs site's top-level sections.
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
  need.

## Reference

Official site: https://diataxis.fr

## Related skills

- [[doc-writer]] / [[doc-reader]] / [[doc-reviewer]] — the agents that write,
  read, and review docs in this architecture.
- [[specs]] — the transient pre-implementation working documents whose durable
  rationale graduates into these docs once a feature ships.
- [[documentation-tooling]] — (future) choosing a generator to publish Diátaxis
  docs (MkDocs, mdBook, Zola)
