# Elicit the next implementation decision

Review the evidence and all recorded decisions. If any implementation choice
remains, ask exactly one question. Ask about the choice with the largest effect
on later work.

A choice is material when a coding agent could reasonably select different
implementation details. These details include files, symbols, interfaces,
algorithms, data flow, errors, compatibility, tests, validation, migration, and
documentation. Ask the user instead of recording an assumption.

List two to five distinct options. Give each option a short label. Describe
the code changes that each option causes. Recommend an option only when project
evidence supports it. Do not ask for facts that documentation or code settles.

Return `ready` only when no coding decision remains. Otherwise return
`question`. Finish with `workflow_output`.
