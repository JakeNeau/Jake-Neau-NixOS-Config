# Why Pi separates writing form from substance

Pi uses one writing system for user replies, documentation, comments, plans, reviews, and interface text. The system has separate form and substance policies.

A form policy can remove common language defects. It cannot decide whether a claim is necessary, supported, connected, or useful. Pi must solve both problems.

## Controlled English supplies the form

The form policy adapts ideas from ASD-STE100 Simplified Technical English. ASD first published the aerospace writing guide in 1986. The standard helps readers understand technical maintenance instructions across language backgrounds.

The Pi policy uses stable terms, common words, active voice, short sentences, and explicit conditions. It also uses one claim or action per sentence. Ordered procedures use one action per numbered step.

The policy is an adaptation for software work. It does not use the controlled ASD-STE100 dictionary and cannot certify compliance.

A [video by Vusal Ismayilov](https://www.youtube.com/watch?v=uJblcC4lKYw) tested a distilled STE skill against common anti-slop instructions. The [published kit](https://github.com/woosal1337/blog/tree/main/videos/ep01-the-cure-for-ai-slop) contains its skill, linter, samples, and results.

The experiment found fewer heuristic form violations with the STE skill. The test covered six tasks and two model families. These results support further testing, not a general proof.

The [official ASD-STE100 site](https://asd-ste100.org/) publishes the standard and its history.

## Claim, support, and meaning supply the substance

A true claim can still produce poor writing. The reader also needs the claim's basis, relation to other claims, and consequence.

Pi builds each nontrivial artifact from six parts:

1. The purpose names the question or required result.
2. The reader model identifies known information and the next need.
3. The claim set keeps only necessary facts, judgments, and recommendations.
4. The support grounds material claims in evidence or explicit reasoning.
5. The relations state mechanisms, causes, limits, contrasts, and trade-offs.
6. The consequence states what the reader must understand, decide, or do.

Each artifact gives these parts a fixed order. A reply starts with its answer. An explanation moves from claim to mechanism, boundary, and implication. A review moves from finding to evidence, impact, and correction.

This structure prevents fact dumping. It also prevents a concise style pass from hiding a missing mechanism or deleting a necessary limit.

## Progressive disclosure protects the context window

Pi's global context contains one writing instruction. That instruction routes prose tasks to `global:skill:writing` through the typed-link registry.

The router contains classification rules and links only. It loads the substance policy for nontrivial claims. It loads the form policy for all authored prose. Comment and documentation policies load only for those artifacts.

Policy bodies remain outside startup context. Pi loads each selected body once per task. This design pays the context cost only when Pi writes prose.

## Separate checks match separate failures

`pi-writing-lint` checks deterministic form rules and reports heuristic candidates. It checks Markdown and plain text after Pi changes those files.

The linter cannot judge truth, relevance, causal reasoning, or significance. Pi reviews those qualities with the substance policy. The `/writing-review` command applies the substance review before form changes.

User-facing output has no mechanical revise-before-send step. Pi checks that output internally before delivery. A future output hook can add enforcement if Pi gains a safe revision event.
