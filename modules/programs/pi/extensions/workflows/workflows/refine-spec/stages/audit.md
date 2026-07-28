# Audit the active specifications

Read the active specifications and compare them with project documentation,
architecture, code, tests, and tracked implementation work. Treat project
documentation as the source for high-level intended behavior. Use code for
verified implementation details.

Find contradictions, ambiguity, missing decisions, missing integration points,
architecture conflicts, likely implementation conflicts, implementation gaps,
and missing acceptance criteria. An implementation gap is not automatically a
design defect.

Rank issues by impact, dependency centrality, safety risk, and evidence
confidence. Give every issue bounded source evidence and a ranking reason. Do
not return issues already listed as skipped unless their evidence changed.

Return `issues` with a ranked queue, or `no-issues` with an empty queue. Finish
with `workflow_output`.
