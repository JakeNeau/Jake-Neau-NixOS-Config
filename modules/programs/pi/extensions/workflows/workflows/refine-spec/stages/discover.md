# Discover the specification system

Read the project documentation before code. Determine how the project stores,
indexes, validates, and retires specifications. Explicit guidance outranks file
and directory names.

Classify the supplied workflow input as `idea`, `focus`, `audit`, or
`ambiguous`. Empty input means `audit`. An idea proposes behavior. A focus names
an area without proposing its design.

Find every plausible specification location. Choose one only when project
evidence supports that choice. If several locations exist, report all of them
and warn that the project should consolidate specification tracking. Do not
create a new convention.

Return the required `spec-context` artifact with `workflow_output`.
