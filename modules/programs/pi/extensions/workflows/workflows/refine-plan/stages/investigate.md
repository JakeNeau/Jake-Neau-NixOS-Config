# Investigate one planning lens

Investigate only the supplied focus and lens. The lens is `specification`,
`documentation`, `implementation`, or `verification`.

Follow project documentation before broad code reads. Use code only for exact
files, symbols, signatures, data structures, call paths, and test seams. Inspect
existing conventions before proposing new structure.

Gather evidence that determines implementation. Record each claim beside its
source excerpt and explain its consequence. Identify constraints, integration
points, and every unresolved implementation decision. Do not silently choose
among viable alternatives.

Do not propose the complete plan, ask the user, or modify files. Return one
`evidence` artifact with `workflow_output`.
