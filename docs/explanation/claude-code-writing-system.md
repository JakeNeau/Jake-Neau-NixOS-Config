# Why Claude Code separates writing form from substance

Claude Code uses one writing system for replies, plans, subagent briefs, review findings, status reports, commit text, documentation, comments, and interface strings. The system splits into a form policy and a substance policy.

A form policy can remove common language defects. It cannot decide whether a claim is necessary, supported, connected, or useful. The system therefore carries one policy for each problem.

## Controlled English supplies the form

The form policy adapts ideas from ASD-STE100 Simplified Technical English. ASD first published that aerospace writing guide in 1986. The standard helps readers understand technical maintenance instructions across language backgrounds.

The adaptation keeps stable terms, common words, active voice, short sentences, and explicit conditions. It allows one claim or action in each sentence. An ordered procedure gives one action to each numbered step.

The policy is an adaptation for software work. It does not use the controlled ASD-STE100 dictionary. It cannot certify compliance with the standard.

A [video by Vusal Ismayilov](https://www.youtube.com/watch?v=uJblcC4lKYw) tested a distilled STE skill against common anti-slop instructions. The [published kit](https://github.com/woosal1337/blog/tree/main/videos/ep01-the-cure-for-ai-slop) contains that skill, its linter, the samples, and the results.

The experiment found fewer heuristic form violations with the STE skill. The test covered six tasks and two model families. These results support further testing, not a general proof.

The [official ASD-STE100 site](https://asd-ste100.org/) publishes the standard and its history.

## Claim, support, and meaning supply the substance

A true claim can still produce poor writing. The reader also needs the basis of the claim, its relation to the other claims, and its consequence.

The substance policy builds each nontrivial artifact from six parts:

1. The purpose names the question to answer or the result to produce.
2. The reader model identifies known information and the next need.
3. The claim set keeps only necessary facts, judgments, and recommendations.
4. The support grounds each material claim in evidence or explicit reasoning.
5. The relations state the mechanism, cause, limit, contrast, or trade-off.
6. The consequence states what the reader must understand, decide, or do.

Each artifact type fixes the order of those parts. A reply starts with its answer. An explanation moves from claim to mechanism, boundary, and implication. A review finding moves from finding to evidence, impact, and correction.

This structure prevents fact dumping. It also stops a concise form pass from hiding a missing mechanism or deleting a necessary limit.

Two failures matter most for an agent. A quoted tool result without its conclusion leaves the reader to judge the evidence. A claim of success without the command that proves it hides the real state of the work.

## Progressive disclosure protects the context window

Claude Code loads every skill description at startup and loads a skill body only on request. A description states when a skill applies. It cannot state the order of work, the exceptions, or the check.

The global context therefore carries one writing instruction. That instruction routes each prose task to the `writing` router skill. The router holds the classification table and the mandatory order of work. It names the substance and form policies that the artifact needs.

Policy bodies stay outside the startup context. Each selected body loads at most once per task. This design pays the context cost only when Claude writes prose.

## Separate checks match separate failures

Form and substance fail in different ways, so each failure gets its own check.

`claude-writing-lint` checks the deterministic form rules and reports heuristic candidates. It runs on Markdown and plain-text files after a change.

The linter cannot judge truth, relevance, causal reasoning, or significance. Only the substance policy reaches those qualities. The `/writing-review` command therefore runs the substance audit before any form change. That order keeps a style pass from erasing a real gap.

A terminal reply has no file to lint and no revise-before-send event. The form policy therefore ends with a checklist to apply before delivery. That checklist is the only guard on conversational output.
