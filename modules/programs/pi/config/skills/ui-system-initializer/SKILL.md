---
name: ui-system-initializer
description: Initialize a project's UI system and authoritative OpenPencil design file before feature UI design. Use when a project lacks verified visual foundations, reusable patterns, OpenPencil bindings, or a project-local ui-system skill.
---

# Initialize a UI system

Initialize the system through concrete user decisions and verified local
OpenPencil resources. Do not design application screens, flows, or features.
Do not name the source book for this method.

## Preconditions

1. Load the project's documentation instructions.
2. Confirm that the project has an established documentation system.
3. Stop if no documentation system exists. Do not create or select one.
4. Discover the project's documentation, design-artifact, skill, validation,
   accessibility, approval, and rollback conventions.
5. Load an existing project-local `ui-system` skill when present.

Do not assume paths such as `docs/`, `.agents/skills/`, or `.pi/skills/`.

## Establish the foundations

Reuse verified decisions. Ask one concrete question at a time for missing
information. Never invent a value to finish initialization.

Record these five areas in the project's documentation system:

1. **Product direction.** Purpose, principal audience, visual character, and
   product constraints.
2. **Hierarchy and composition.** Content and action hierarchy, grouping,
   density, widths, responsive composition, and breakpoint behavior.
3. **Visual foundations.** Record concrete values and named roles.

Address each applicable foundation:

   - typography
   - color
   - spacing and sizing
   - surfaces and depth
   - imagery and iconography
   - responsive behavior
4. **Reusable patterns.** Purpose, anatomy, variants, states, content
   constraints, and use rules for patterns required now.
5. **OpenPencil bindings.** The project-relative `.fig` file, pages, variables,
   components, variants, assets, and stable node identifiers.

Mark a foundation as not applicable only when the project records a reason.
Keep accessibility requirements separate from the visual method.

## Mutate safely

Before changing files or OpenPencil state:

1. Present the proposed paths, resources, and effects.
2. Obtain user approval.
3. Use the `openpencil` tool to search for the required MCP operation.
4. Inspect current state before mutation.
5. Make small mutations against explicit document and page identifiers.
6. Save the authoritative `.fig` file inside the project.

Never call OpenPencil's unrestricted `eval` capability. Never place design
artifacts outside the trusted project.

## Verify readiness

Use a fresh inspection path after mutation. Inspect the saved `.fig` file with
the `openpencil` CLI and run applicable project validation commands.

Readiness passes only when:

- all five areas contain concrete project decisions
- each applicable foundation has values, roles, and use rules
- every documented OpenPencil resource exists
- every recorded identifier resolves to the intended resource
- inspected variables and components agree with the documentation
- every durable artifact exists
- the generated skill resolves the same resources
- applicable validation commands pass

Report every missing or inconsistent item. Do not invent content to make the
check pass.

## Generate the project skill

After readiness passes, create a project-local skill named `ui-system` through
the project's discovered skill convention. The skill must locate rather than
duplicate the UI-system documentation.

The generated skill must:

- trigger for UI-system, OpenPencil, and feature UI design work
- locate the UI-system documentation and authoritative `.fig` file
- record required page, variable, component, and node identifiers
- name the `openpencil` tool and CLI as the approved interfaces
- require a readiness preflight before feature design
- require reuse of documented foundations and patterns
- require system extension before introducing a missing decision
- forbid invented design decisions
- preserve the project's accessibility requirements

Use valid Agent Skills frontmatter. Prefer relative references when the project
convention permits them.

## Completion

Report the initialized system and stop. Do not continue into feature UI design.
