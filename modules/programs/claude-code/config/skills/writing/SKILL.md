---
name: writing
description: Routes every prose task through the house writing system. It classifies the artifact, orders substance before form, protects exact text, and names the claude-writing-lint check. Use before writing or revising any prose. This covers terminal replies, plans, subagent briefs, review findings, status reports, commit and pull-request text, TODO entries, documentation, comments, and interface strings.
---

# Writing router

Claude Code loads every skill description at startup and loads a body with the
`Skill` tool. A description states when a skill applies. It cannot state the
order of work, the exceptions, or the check. This router holds those rules.

## Order of work

1. Classify the artifact with the table below.
2. Load each policy that the matching row names.
3. Build the substance before you apply the form rules.
4. Run `claude-writing-lint` on each changed Markdown or plain-text file.

The order is mandatory. A form pass must never hide a missing mechanism or
delete a necessary limit. Load each policy at most once per task.

## Classify the artifact

| Artifact | Policies to load |
|---|---|
| Terminal reply to the user | [[skill:writing-substance]], [[skill:controlled-writing]] |
| Plan-mode plan or spec | [[skill:writing-substance]], [[skill:controlled-writing]] |
| Subagent brief or task handoff | [[skill:writing-substance]], [[skill:controlled-writing]] |
| Code-review finding | [[skill:writing-substance]], [[skill:controlled-writing]] |
| Status or progress report | [[skill:writing-substance]], [[skill:controlled-writing]] |
| Commit message or pull-request text | [[skill:writing-substance]], [[skill:controlled-writing]] |
| TODO entry | [[skill:controlled-writing]] |
| Documentation page | [[skill:documentation]] and [[skill:diataxis]] first, then both writing policies |
| Code comment | [[skill:comments]] first, then [[skill:controlled-writing]] |
| Error message or other interface string | [[skill:controlled-writing]] |

A mixed artifact takes every matching row. A plan that documents a new
capability therefore loads the documentation policies too.

## Exceptions

A short acknowledgment needs the form policy alone. A one-line confirmation and
a direct answer that carries no material claim both qualify.

Never restyle exact code, identifiers, commands, file paths, quotations, API
names, tool output, legal text, generated text, or machine directives. Accuracy
outranks every form limit.

## The mechanical check

After you change a standalone prose file, run the linter:

```sh
claude-writing-lint <file>
```

The linter reports deterministic form violations and heuristic candidates.
Resolve each valid finding. Report a heuristic exception with its reason instead
of distorting accurate text. Do not lint a whole source file to reach an
embedded comment or interface string. Review that prose against the loaded
policies instead.

A terminal reply has no file to lint. Apply the form policy's final check before
you send it.

## Related skills

- [[skill:writing-substance]]: select, support, connect, and order the content.
- [[skill:controlled-writing]]: apply the controlled-English form rules.
- [[skill:comments]]: decide whether a code comment exists and what it says.
- [[skill:documentation]]: choose the documentation type and where it belongs.
- [[skill:diataxis]]: keep tutorials, how-to guides, reference, and explanation separate.
- [[skill:using-skills]]: the general rule that this router applies to prose.
