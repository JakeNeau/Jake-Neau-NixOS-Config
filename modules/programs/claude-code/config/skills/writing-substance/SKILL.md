---
name: writing-substance
description: Governs what to say and how to order it, through purpose, reader, necessary claims, support, relations, and consequence. It makes each artifact show what is true, why it is true, how the ideas connect, and why they matter. Use for any material claim, explanation, recommendation, plan, review finding, decision, documented behavior, or nontrivial reply.
---

# Substantive writing

A true claim can still produce poor writing. The reader also needs the basis of
the claim, its relation to the other claims, and its consequence.

Build a content model before you draft:

1. **Purpose:** Name the question to answer or the result to produce.
2. **Reader:** Identify what the reader knows and needs next.
3. **Claims:** Keep only necessary facts, judgments, and recommendations.
4. **Support:** Ground each material claim in observation, sources, tests, code behavior, or explicit reasoning.
5. **Relations:** State the mechanism, cause, contrast, limit, or trade-off that connects the claims.
6. **Consequence:** State what the reader must understand, decide, or do.

Use **claim, support, meaning** as the shared test. Do not print these labels
unless the artifact needs them. True facts without a clear relationship or
significance are not sufficient.

## Artifact structures

| Artifact | Required order |
|---|---|
| Terminal reply | answer, support, consequence or next action |
| Plan or spec | goal, ordered steps, risks, validation |
| Subagent brief | task, context and constraints, required output |
| Code-review finding | finding, evidence, impact, correction |
| Status report | result, evidence, remaining issue |
| Commit message | change, reason, consequence |
| Pull-request text | purpose, change summary, validation, known risk |
| TODO entry | required work, reason, location |
| Explanation | claim, mechanism, boundary, implication |
| Procedure or how-to guide | condition, action, expected result |
| Reference page | subject, exact behavior, constraints and exceptions |
| Decision | choice, reasons, alternatives or trade-offs |
| Code comment | hidden reason or invariant, consequence |
| Interface string | what happened, what the reader must do |

Apply the matching structure to each section of a mixed document. Compress a
short answer instead of printing an empty slot.

## Substance audit

Remove content that fails one of these tests:

- A material claim has no support or states more certainty than its support allows.
- A fact does not serve the purpose.
- A conclusion repeats or appears after unnecessary background.
- A causal claim names no mechanism.
- Evidence appears without the conclusion that it establishes.
- A benefit names no concrete actor and effect.
- A citation, caveat, or background detail changes no confidence, understanding, or action.

When a claim lacks support, remove it, mark the uncertainty, or ask for the
missing information. Never invent support to improve fluency.

Two failures matter most for an agent. A tool result quoted without its
conclusion leaves the reader to judge the evidence. A claim of success without
the command that proves it hides the real state of the work.

## Related skills

- [[skill:writing]]: route the complete prose task.
- [[skill:controlled-writing]]: apply the form rules after the substance is complete.
