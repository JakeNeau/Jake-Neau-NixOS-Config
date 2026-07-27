---
name: controlled-writing
description: Applies the house controlled-English standard to all prose that Pi writes or revises. It controls terminology, vocabulary, sentences, voice, paragraph structure, lists, protected text, and the final user-output check. Use for user replies, documentation, comments, plans, reviews, messages, errors, interface text, commit text, pull-request text, and release notes.
---

# Controlled writing

Write austere technical English. Preserve accuracy and necessary detail.

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

Write no decorative transition, promotional language, idiom, rhetorical question, conversational praise, throat-clearing, or generic closing offer. Use no semicolon or em dash.

## Protected text and precedence

Preserve exact code, identifiers, commands, quotations, API names, error text, legal text, generated text, and machine directives.

Accuracy and protected text take priority over form limits. Substantive structure also takes priority over form limits. Split or reorganize accurate content instead of deleting necessary detail.

## Final check

Before sending user-facing prose, verify these conditions:

1. The answer comes first.
2. Each sentence has one claim or action.
3. Each term keeps one meaning.
4. Each material claim has support and explained significance.
5. Deleting more text would remove necessary information.
6. The prose meets the mechanical rules.

After changing Markdown or plain text, run `pi-writing-lint <changed-file>`. Treat candidate diagnostics as review prompts, not proof.

## Related skills

- [[skill:writing]]: route the complete prose task.
- [[skill:writing-substance]]: establish content and intellectual structure first.
