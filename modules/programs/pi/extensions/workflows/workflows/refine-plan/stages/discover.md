# Discover the specification and plan system

Read project documentation before code. Determine how the project stores,
indexes, validates, and retires specifications and plans. Explicit guidance
outranks names and directory heuristics.

The canonical specification root is `specs/` unless project documentation names
a different authority. Search that root recursively without a depth limit.
Plans must remain in the same directory as their specifications. Do not assume a
filename convention. If a plan-to-specification association is ambiguous, leave
it unresolved for later clarification.

Classify the workflow input as `idea`, `focus`, `audit`, or `ambiguous`. Empty
input means `audit`. An idea requests a new implementation plan. A focus names a
specification or existing plan. Audit mode checks all active plans.

Find every plausible specification location. Choose one only when documentation
supports the choice. Report split locations as a warning. Do not create a new
project convention.

Return the required `spec-context` artifact with `workflow_output`.
