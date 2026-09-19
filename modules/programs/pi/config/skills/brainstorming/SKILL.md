---
name: brainstorming
description: Turn an idea into an approved, project-aligned design before implementation. Use for explicit brainstorming requests and changes with unresolved product, behavior, or architecture decisions. Inspect evidence, resolve one decision at a time, compare approaches, validate the design, and write its specification for Pi's /refine-plan workflow.
---

# Brainstorm a design

Turn the idea into an approved specification. Keep the process proportional to
the change.

## Gate implementation

Before design approval, do not write implementation files, scaffold, create an
implementation plan, or start implementation. You may inspect evidence and
discuss the design. A small change needs a small design, not a skipped design.

## 1. Establish context

Read the project's documentation before code for high-level behavior. Inspect
relevant code and history only as needed. Learn the existing architecture,
conventions, current behavior, specification format, and acceptance criteria.

Answer repository questions from evidence instead of asking the user. Separate
confirmed facts from assumptions. If the request spans independent subsystems,
propose boundaries and ordering. Ask which bounded part to design first.

## 2. Resolve decisions

Ask one material question per turn. Stop asking when the purpose, scope,
constraints, and success criteria are clear.

Call `ask_user` only when you need the user to choose. Offer concise options.
Put the recommended option first and explain its decisive trade-off. Omit
previews unless concrete code or configuration helps comparison. Do not ask
low-value preference questions.

## 3. Compare approaches

Present two or three viable approaches with relevant trade-offs and a
recommendation. Compare only factors that can change the decision, such as
complexity, compatibility, maintenance, migration risk, or reversibility. If
only one approach is credible, state why instead of inventing alternatives.
Obtain the user's choice when it affects the design.

## 4. Validate the design

Present a design that covers only applicable concerns:

- scope, observable behavior, and non-goals
- component boundaries, interfaces, dependencies, and data flow
- failures, validation, compatibility, and rollout
- verification and acceptance criteria

Follow existing patterns and exclude unrelated refactoring. Use one approval
checkpoint for a compact design. Split a complex design into a few coherent
checkpoints. The final checkpoint must request explicit design approval and
propose the exact specification path. Do not write the file before approval.

## 5. Write and review the specification

Use the project's established specification location and format. When the
project uses this Nix repository's convention, create
`specs/<short-kebab-name>.md` with this structure:

```markdown
## Spec

[approved design]

## Plan

## Tasks
```

Fill only `## Spec`. Do not add unapproved scope or implementation planning.
Review the file for placeholders, contradictions, ambiguity, unsupported
claims, missing acceptance criteria, and excessive scope. Fix defects, then ask
the user to approve the exact file. Repeat review after requested changes.

After file approval, stop and direct the user to `/refine-plan <spec-path>`.
Do not begin planning or implementation.
