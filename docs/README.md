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

Within a quadrant, pages group into subfolders only when the grouping is
earned — several pages (≈3+) sharing a theme; never a single-file or
speculative empty folder. Today the one earned group is
[`how-to/declarations/`](how-to/declarations/), the recipes for adding to the
flake's structured declarations (hosts, users, programs, secrets); the
remaining how-to pages stay flat. Keep this index in step with any
reorganization.

## How this project's documentation fits together

- **`README.md`** (repo root) — the project front page: what this flake is,
  how it's built, and where to start.
- **`docs/`** (this tree) — the source of truth for *understanding* the repo:
  how it works at a high level, in the four quadrants above, for humans and
  agents alike. Consult it before the code; code is for low-level detail.
- **`.agents/skills/nix-config/`** — the operational guide for *changing* the
  repo: what to read before adding or editing anything. It states each action
  briefly and links into these pages for depth.
- **`AGENTS.md`** — standing instructions for agents working in the repo
  (validation commands, cautions, conventions).
- **`specs/`** — transient pre-implementation design documents: written before
  a change, deleted once the durable rationale has graduated into
  `explanation/`.
