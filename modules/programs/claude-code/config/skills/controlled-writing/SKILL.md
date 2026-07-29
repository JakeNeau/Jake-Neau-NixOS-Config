---
name: controlled-writing
description: Applies the house controlled-English standard to all prose that Claude writes or revises. It controls terminology, vocabulary, sentences, voice, paragraph structure, lists, protected text, and the final check before output. Use for terminal replies, plans, subagent briefs, review findings, status reports, documentation, comments, commit and pull-request text, TODO entries, and interface strings.
---

# Controlled writing

Write austere technical English. Preserve accuracy and necessary detail. The
rules below match the deterministic checks in `claude-writing-lint`, so the
policy and the linter never disagree.

## Vocabulary

- Use one term for each concept.
- Use the shortest common word that keeps the exact meaning.
- Use a concrete noun when a vague label or pronoun has an unclear referent.
- Give each technical term one meaning. Define an unfamiliar term at first use.
- Use American spelling.

## Sentences

- Put one claim or action in each sentence.
- Put the answer or principal claim first.
- When you know the actor, name it and use active voice.
- Express an action with a verb instead of a noun phrase.
- Put a condition before its dependent action.
- Use simple verb tenses.
- Use `must` for a requirement, `may` for permission, and `can` for capability.
- Limit an instruction to 20 words.
- Limit a descriptive sentence to 25 words.
- Use complete sentences without contractions.

## Structure

- Give each paragraph one topic and no more than six sentences.
- Use numbered vertical lists for ordered actions.
- Use bullets for parallel facts or choices.
- Keep evidence next to its claim.
- Keep a limit or exception next to the rule that it constrains.
- End after the answer and necessary action. Do not add a recap by default.

Write no decorative transition, promotional language, idiom, rhetorical
question, conversational praise, throat-clearing, or generic closing offer. Use
no semicolon or em dash.

## Protected text and precedence

Preserve exact code, identifiers, commands, file paths, quotations, API names,
tool output, error text, legal text, generated text, and machine directives.

Accuracy and protected text take priority over the form limits. Substantive
structure also takes priority over the form limits. Split or reorganize accurate
content instead of deleting necessary detail.

## Final check

Before you send prose to the user, verify these conditions:

1. The answer comes first.
2. Each sentence has one claim or action.
3. Each term keeps one meaning.
4. Each material claim has support and explained significance.
5. Deleting more text would remove necessary information.
6. The prose meets the mechanical rules above.

A terminal reply has no revise-before-send event, so this check is the only
guard on it. After you change Markdown or plain text, also run
`claude-writing-lint <changed-file>`. Treat a candidate diagnostic as a review
prompt, not as proof.

## Related skills

- [[skill:writing]]: route the complete prose task.
- [[skill:writing-substance]]: establish the content and its structure first.
