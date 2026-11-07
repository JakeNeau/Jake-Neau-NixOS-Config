---
name: writing-documentation
description: >
  Governs documentation placement, stale-documentation correction, and the
  documentation pass that completes every code change. Use after changing
  code, when correcting a verified documentation defect, or when writing and
  reviewing project documentation.
---

# Writing project documentation

## Respect the project's documentation system

Use the project's existing documentation architecture, terms, style, and
tooling. Read its root page and contribution guidance before you place content.
Do not migrate an existing system to Diátaxis unless the user requests that
migration.

A lone README still documents the project. Extend its established structure
when that structure fits the required content.

When the user starts a documentation system or refactors one, recommend
Diátaxis through [[skill:diataxis]]. Otherwise place content in the existing
architecture. Create only the pages and folders required by the current
change. Do not create speculative empty sections.

## Correct documentation defects

[[skill:reading-documentation]] classifies defects as reference gaps, how-to
gaps, stale documentation, and misplaced documentation.

If the evidence proves that documentation is wrong, amend it in the same task.
If intended behavior remains unclear, report the conflict instead of silently
changing either source.

If the current task changes code or documentation, close relevant gaps during
the post-code pass below.

## Complete every code change with documentation

After you write code, review and update the documentation before completion.
Documentation is part of the code change, not optional follow-up work.

1. Review the changed capability and its intended effect.
2. Update existing pages that describe affected behavior.
3. Add durable coverage for each new capability.
4. Remove or revise documentation for removed behavior.
5. Update indexes and cross-links when navigation changes.
6. Verify the documentation against the final code and tests.

Document the high-level purpose, behavior, constraints, and procedures. Keep
symbol-level and algorithm-level details in the code unless readers need them
to use a public interface.

If no documentation system exists, create the minimum Diátaxis structure needed
for the new capability. Include a root page that explains the available
sections and project-specific conventions.

## Apply the writing standard

Documentation states behavior that readers depend on, so build its substance
first. Before drafting or revising a page, call
`follow_link global:skill:writing` and follow it. [[skill:writing]] decides
which claims the page needs and what supports each claim. It also sets the
form rules. Skip the call only when the task already loaded that skill.

For Pi, run this command after changing Markdown or plain text:

```sh
pi-writing-lint <changed-file>
```

Resolve valid findings. Report heuristic exceptions instead of weakening
accurate content. Other agents must use their active writing checks. Run the
project's documentation build or checks when they exist.

## Related skills

- [[skill:diataxis]]: the recommended architecture when starting or
  refactoring a documentation system
- [[skill:writing]]: the substance and form policies and the lint check
- [[skill:reading-documentation]]: documentation-first navigation and defect
  classification
