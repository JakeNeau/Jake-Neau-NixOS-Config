---
description: Review prose for substance, presentation, and controlled-English form
argument-hint: "[scope]"
---

Review and automatically conform prose in this scope:

${ARGUMENTS:-prose changed in `git diff HEAD`}

First call `follow_link global:skill:writing` and load every policy that the scope requires. Work in this order:

1. Identify prose in scope without changing code logic.
2. Establish the applicable sources of truth.
3. Audit each claim, its support, its relation to other claims, and its consequence.
4. Remove unsupported, irrelevant, repeated, or hollow material.
5. Apply the required artifact structure and controlled-English policy.
6. Run `pi-writing-lint` on supported Markdown and plain-text files.
7. Resolve valid findings and record explained heuristic exceptions.

For code comments, follow the comment policy before changing their form. Preserve exact code, identifiers, commands, quotations, directives, legal notices, generated content, and error text.

If evidence cannot support a claim, remove it, mark the uncertainty, or report the missing information. Do not invent support. Do not rewrite unrelated prose solely to clear existing linter findings.

Finish with counts for unsupported claims removed, claims clarified, structures corrected, form violations fixed, and exceptions retained.
