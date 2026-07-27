---
name: documentation
description: >
  Governs documentation-first navigation, gap reporting, stale-documentation
  correction, post-code documentation, and documentation placement. Use before
  code investigation, after code changes, or when writing and reviewing project
  documentation.
---

# Project documentation discipline

## Navigate from documentation to code

Treat project documentation as the source of truth for high-level behavior.
This behavior includes architecture, system flows, interfaces, and operating
procedures.

Before reading code for those subjects:

1. Find the documentation root, generator configuration, and main index.
2. Read the relevant pages and their local navigation.
3. Use code only for low-level implementation details.

Low-level details include exact symbols, algorithms, data structures, and
control flow. If code reveals missing high-level information, record a
documentation gap immediately.

Record these facts for each gap:

- the missing information
- the code or test that supplied it
- the documentation section that should contain it

Tell the user about every gap at the task's natural end. State that the missing
information belongs in the project documentation.

## Respect the project's documentation system

Use the project's existing documentation architecture, terms, style, and
tooling. Read its root page and contribution guidance before you place content.
Do not migrate an existing system to Diátaxis unless the user requests that
migration.

A lone README still documents the project. Read it before code, and
extend its established structure when that structure fits the required content.

When no existing architecture determines placement, use Diátaxis through
[[skill:diataxis]]. Create only the pages and folders required by the current
change. Do not create speculative empty sections.

Do not create a documentation system during a read-only investigation. Report
that the project has no documentation system. The post-code requirement below
is different because new code requires durable documentation.

## Handle documentation defects

Classify documentation defects by their effect:

- **Reference gap:** You needed code to discover high-level behavior or
  structure.
- **How-to gap:** Work revealed a reusable procedure that the documentation
  omitted.
- **Stale documentation:** Verified behavior contradicts the documentation.
- **Misplaced documentation:** Correct content appears in the wrong section for
  the project's architecture.

Do not assume that code wins when code and documentation disagree. Use tests,
project policy, and the task's requirements to determine intended behavior.

If the evidence proves that documentation is wrong, amend it in the same task.
If intended behavior remains unclear, report the conflict instead of silently
changing either source.

For a gap found during read-only work, ask before adding documentation. If the
current task already changes code or documentation, close relevant gaps during
the required documentation pass.

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

Before drafting or revising documentation, follow the active writing policy and
the project's local style. Pi must call `global:skill:writing` unless it already
loaded that skill for the task.

For Pi, run this command after changing Markdown or plain text:

```sh
pi-writing-lint <changed-file>
```

Resolve valid findings. Report heuristic exceptions instead of weakening
accurate content. Other agents must use their active writing checks. Run the
project's documentation build or checks when they exist.

## Related skills

- [[skill:diataxis]]: the default architecture when the project has no existing
  documentation system
