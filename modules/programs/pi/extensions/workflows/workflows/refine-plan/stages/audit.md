# Audit active implementation plans

Read active specifications and their plans recursively. Compare each plan with
project documentation, architecture, code, tests, and current implementation.
Treat documentation as the source for high-level behavior. Use code for exact
symbols and control flow.

Find missing plans, specification conflicts, undecided implementation details,
stale paths or symbols, incomplete data flow, missing error behavior, missing
tests, and missing documentation work. A complete plan leaves no implementation
decision for the coding phase.

Rank issues by impact, dependency order, safety risk, and evidence confidence.
Give every issue bounded source evidence and a ranking reason. Do not return a
skipped issue unless its evidence changed.

Return `issues` with a ranked queue, or `no-issues` with an empty queue. Finish
with `workflow_output`.
