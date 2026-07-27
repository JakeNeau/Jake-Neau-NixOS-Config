---
name: writing
description: Routes every Pi prose task through the house writing system with progressive disclosure. It selects substance, controlled-English, documentation, and comment policies without placing their bodies in startup context. Use before writing or revising user replies, documentation, comments, plans, reviews, errors, interface text, commit text, pull-request text, or release notes.
---

# Writing router

Classify the artifact before drafting. Load each selected policy at most once per task.

1. For code comments, first call `follow_link global:skill:comments`.
2. For documentation architecture or placement, first call `follow_link global:skill:documentation`.
3. For a material claim, explanation, recommendation, documented behavior, or nontrivial reply, call `follow_link global:skill:writing-substance`.
4. For all authored prose, call `follow_link global:skill:controlled-writing`.

Build the substance before applying the form rules. A short acknowledgment needs only the controlled-writing policy. Exact code, identifiers, commands, quotations, legal text, generated text, and machine directives remain unchanged.

After changing a Markdown or plain-text file, run:

```sh
pi-writing-lint <changed-file>
```

Resolve valid findings. Report heuristic exceptions instead of distorting accurate text. Do not lint an entire source file to check embedded comments or interface strings. Review that prose with the loaded policies.

## Related skills

- [[skill:writing-substance]]: select, support, connect, and order the content.
- [[skill:controlled-writing]]: apply the controlled-English form and final check.
- [[skill:comments]]: decide whether a code comment exists and what it says.
- [[skill:documentation]]: establish documentation type, architecture, and placement.
