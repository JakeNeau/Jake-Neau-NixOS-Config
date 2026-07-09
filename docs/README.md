# Documentation

This tree is organized with the [Diátaxis](https://diataxis.fr/) architecture:
four kinds of documentation, one folder each, and every page is exactly one
kind.

- **[`tutorials/`](tutorials/)** — learning-oriented lessons. You follow along
  to gain confidence with the system; the page decides what you do.
- **[`how-to/`](how-to/)** — task-oriented recipes. You arrive with a goal and
  get just the steps to reach it.
- **[`reference/`](reference/)** — information-oriented description of the
  machinery: dry, complete, and accurate. It describes; it never explains.
- **[`explanation/`](explanation/)** — understanding-oriented background: why
  things work the way they do, the alternatives, and the trade-offs.

When a topic needs more than one kind of coverage it gets one page per kind,
cross-linked — rationale is never smuggled into a recipe or a reference page.

## How this project's documentation fits together

- **`README.md`** (repo root) — the project front page: what this flake is,
  how it's built, and where to start.
- **`docs/`** (this tree) — the human-facing documentation, in the four
  quadrants above.
- **`.agents/skills/nix-config/`** — the agent-facing entry point: the
  operational guide AI agents read before changing the repo. It states each
  action briefly and links into these pages for depth.
- **`AGENTS.md`** — standing instructions for agents working in the repo
  (validation commands, cautions, conventions).
- **`specs/`** — transient pre-implementation design documents: written before
  a change, deleted once the durable rationale has graduated into
  `explanation/`.
