# Verify the implementation plan

Read the specification, written plan, project documentation, relevant code, and
tests. Compare them with the accepted proposal and every user decision. Run
documented read-only checks when available.

Fail when the plan is outside its specification directory. Fail for an omitted
decision, architecture conflict, stale path or symbol, or missing dependency
order. Fail for unclear function behavior or incomplete data and control flow.
Fail for unspecified errors, compatibility, tests, documentation, or unrelated
scope. Fail whenever coding would require another decision.

Give every finding a concrete correction. Return `passed` only when the plan
fully defines implementation. Otherwise return `failed`. Finish with
`workflow_output`.
