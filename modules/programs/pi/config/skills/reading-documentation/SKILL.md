---
name: reading-documentation
description: >
  Governs documentation-first navigation and documentation-gap reporting. Use
  before code investigation, to learn how a project works at a high level, and
  whenever code reveals information that the documentation should hold.
---

# Reading project documentation

## Navigate from documentation to code

Treat project documentation as the source of truth for high-level behavior.
This behavior includes architecture, system flows, interfaces, and operating
procedures.

Before reading code for those subjects:

1. Find the documentation root, generator configuration, and main index.
2. Read the relevant pages and their local navigation.
3. Use code only for low-level implementation details.

Low-level details include exact symbols, algorithms, data structures, and
control flow.

## Respect the project's documentation system

Read the project's root page and contribution guidance before you search for a
subject. The project's own architecture and terms decide where information
lives. When the project follows Diátaxis, [[skill:diataxis]] tells you which
type of page answers which need. A how-to guide holds a task, reference holds
structure and behavior, and explanation holds rationale.

A lone README still documents the project. Read it before code.

Do not create a documentation system during a read-only investigation. Report
that the project has no documentation system.

## Report documentation defects

If code reveals missing high-level information, record a documentation gap
immediately. Record these facts for each gap:

- the missing information
- the code or test that supplied it
- the documentation section that should contain it

Classify each defect by its effect:

- **Reference gap:** You needed code to discover high-level behavior or
  structure.
- **How-to gap:** Work revealed a reusable procedure that the documentation
  omitted.
- **Stale documentation:** Verified behavior contradicts the documentation.
- **Misplaced documentation:** Correct content appears in the wrong section for
  the project's architecture.

Do not assume that code wins when code and documentation disagree. Use tests,
project policy, and the task's requirements to determine intended behavior.

Tell the user about every gap at the task's natural end. State that the missing
information belongs in the project documentation. For a gap found during
read-only work, ask before adding documentation. If the current task already
changes code or documentation, close the gap through
[[skill:writing-documentation]].

## Related skills

- [[skill:diataxis]]: which documentation type answers which reader need
- [[skill:writing-documentation]]: correcting defects and documenting code
  changes
