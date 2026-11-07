---
name: writing
description: The house writing standard for every Pi prose task. It decides what to claim and in what order, then applies the controlled-English form and final check. Use before writing or revising user replies, documentation, comments, plans, reviews, errors, interface text, commit text, pull-request text, or release notes.
---

# Writing

Build the substance first. Apply the form rules second. A form pass must never
hide a missing mechanism or delete a necessary limit.

For a code comment, first call `follow_link global:skill:writing-comments`.
For documentation placement, first call
`follow_link global:skill:writing-documentation`. A short acknowledgment needs
only the form rules.

## Substance

Build a content model before drafting:

1. **Purpose:** Name the question to answer or the result to produce.
2. **Reader:** Identify what the reader knows and needs next.
3. **Claims:** Keep only necessary facts, judgments, and recommendations.
4. **Support:** Ground each material claim in observation, sources, tests, code behavior, or explicit reasoning.
5. **Relations:** State the mechanism, cause, contrast, limit, or trade-off that connects the claims.
6. **Consequence:** State what the reader must understand, decide, or do.

Use **claim, support, meaning** as the shared test. Do not print these labels
unless the artifact needs them. True facts without a clear relationship or
significance are not sufficient.

### Artifact structures

| Artifact | Required order |
|---|---|
| User reply | answer, support, consequence or next action |
| Explanation | claim, mechanism, boundary, implication |
| Procedure | condition, action, expected result |
| Decision | choice, reasons, alternatives or trade-offs |
| Reference | subject, exact behavior, constraints and exceptions |
| Review | finding, evidence, impact, correction |
| Comment | hidden reason or invariant, consequence |
| Status report | result, evidence, remaining issue |

Apply the matching structure to each section of a mixed document. Compress
short answers instead of printing empty slots.

### Substance audit

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

## Form

Write austere technical English. Preserve accuracy and necessary detail.

### Vocabulary

- Use one term for each concept.
- Use the shortest common word that keeps the exact meaning.
- Use a concrete noun when a vague label or pronoun has an unclear referent.
- Give each technical term one meaning.
- Use American spelling.

### Sentences

- Put one claim or action in each sentence.
- When you know the actor, name it and use active voice.
- Express an action with a verb instead of a noun phrase.
- Put a condition before its dependent action.
- Use simple verb tenses.
- Use `must` for a requirement, `may` for permission, and `can` for capability.
- Limit an instruction to 20 words.
- Limit a descriptive sentence to 25 words.
- Use complete sentences without contractions.
- Use no semicolon or em dash.

### Structure

- Give each paragraph one topic and no more than six sentences.
- Use numbered vertical lists for ordered actions.
- Use bullets for parallel facts or choices.
- Keep evidence next to its claim.
- Keep a limit or exception next to the rule that it constrains.

### Protected text and precedence

Preserve exact code, identifiers, commands, quotations, API names, error text,
legal text, generated text, and machine directives.

Accuracy and protected text take priority over form limits. Substantive
structure also takes priority over form limits. Split or reorganize accurate
content instead of deleting necessary detail.

## Final check

Before sending user-facing prose, verify these conditions:

1. Each sentence has one claim or action.
2. Each term keeps one meaning.
3. Each material claim has support and explained significance.
4. Deleting more text would remove necessary information.
5. The prose meets the mechanical rules.

After changing a Markdown or plain-text file, run:

```sh
pi-writing-lint <changed-file>
```

Resolve valid findings. Report heuristic exceptions instead of distorting
accurate text. Do not lint an entire source file to check embedded comments or
interface strings. Review that prose with this skill instead.

## Related skills

- [[skill:writing-comments]]: decide whether a code comment exists and what it says.
- [[skill:writing-documentation]]: establish documentation architecture and placement.
