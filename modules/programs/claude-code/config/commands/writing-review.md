---
description: Review prose for substance, presentation, and controlled-English form
argument-hint: "[scope]"
---

Review and conform the prose in this scope:

$ARGUMENTS

When the scope above is empty, use the prose changed in `git diff HEAD`. A
supplied path, directory, or commit range replaces that default.

Load [[skill:writing]] with the `Skill` tool, then load every policy that the
scope requires. Work in this order:

1. Identify the prose in scope. Change no code logic.
2. Establish the applicable sources of truth.
3. Audit each claim, its support, its relation to the other claims, and its consequence.
4. Remove unsupported, irrelevant, repeated, or hollow material.
5. Apply the required artifact structure and the controlled-English policy.
6. Run `claude-writing-lint` on each supported Markdown and plain-text file.
7. Resolve the valid findings. Record each retained heuristic exception with its reason.

For a code comment, follow [[skill:comments]] before you change its form.
Preserve exact code, identifiers, commands, quotations, machine directives,
legal notices, generated content, and tool output.

When the evidence cannot support a claim, remove the claim, mark the
uncertainty, or report the missing information. Do not invent support. Do not
rewrite unrelated prose only to clear an existing linter finding.

Finish with counts for unsupported claims removed, claims clarified, structures
corrected, form violations fixed, and exceptions retained.
