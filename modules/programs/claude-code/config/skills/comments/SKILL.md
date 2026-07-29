---
name: comments
description: Routes every added or modified code comment through the house style by classifying its purpose, loading only the matching focused policy, and applying shared rules for sparsity, concision, placement, proximity, and real dependencies. Use before writing, changing, placing, or reviewing any code comment in any language.
---

# Comment style router

Comments are exceptional. Before adding or modifying one, classify it using the
table below and follow only the matching focused skill. If no category justifies
the comment, write nothing.

## Shared rules

- **Earn the line.** A comment must add information a competent reader cannot
  recover from the code, names, types, or signature.
- **Stay sparse.** Ordinary prose targets one line. Use a second only for a
  necessary consequence or removal condition; never use a third.
- **Keep one idea per comment.** Delete preambles, hedging, history, and filler.
- **Place it locally.** Put a comment beside the exact code it explains.
  Multi-line comments go above the code; terse same-line comments are fine.
- **Split narration.** Break a top-level block covering several steps into the
  smallest comments beside the relevant steps. Keep a high-level comment only
  when it genuinely spans the whole unit.
- **Name real dependencies only.** A reusable module describes its own contract,
  not callers or downstream consumers it does not import or use.
- **Preserve code.** A comment review may delete, rewrite, split, or relocate
  comments, but must not change code logic.

## Classify, then follow

| Purpose | Action |
|---|---|
| Restates code, names, types, or signatures | Follow [[skill:comment-redundant-narration]] |
| Explains a non-obvious design choice | Follow [[skill:comment-intent-rationale]] |
| States a condition that must remain true | Follow [[skill:comment-invariants]] |
| Explains an external limitation or compatibility fix | Follow [[skill:comment-workarounds]] |
| Documents a caller-visible contract | Follow [[skill:comment-api-contracts]] |
| Marks a meaningful section or test phase | Follow [[skill:comment-structural-markers]] |
| Carries machine-readable comment syntax | Follow [[skill:comment-functional-directives]] |
| Carries legal, ownership, generated, or vendored metadata | Follow [[skill:comment-provenance]] |
| Records deferred work with TODO, FIXME, or HACK | Follow [[skill:comment-task-markers]] |
| Contains disabled source code | Follow [[skill:comment-disabled-code]] |

A comment may have more than one purpose. Load each applicable skill, preserve
functional or provenance text exactly, and classify adjacent human prose
separately. Load each category at most once per task.

## Related skills

- [[skill:comment-redundant-narration]] — delete comments that merely say what code says.
- [[skill:comment-intent-rationale]] — write concise reasons for surprising choices.
- [[skill:comment-invariants]] — state constraints and their consequences.
- [[skill:comment-workarounds]] — explain external limitations and removal conditions.
- [[skill:comment-api-contracts]] — document caller-visible guarantees.
- [[skill:comment-structural-markers]] — use section and test-phase markers sparingly.
- [[skill:comment-functional-directives]] — preserve machine-readable directives.
- [[skill:comment-provenance]] — preserve legal and generated notices.
- [[skill:comment-task-markers]] — route deferred work to project tracking.
- [[skill:comment-disabled-code]] — remove source code hidden in comments.
