---
name: receiving-code-review
description: How to respond to code review feedback with technical rigor instead of performative agreement — read all of it first, verify each item against the codebase before implementing, ask when anything is unclear, push back with technical reasoning when a suggestion is wrong, and never open with "You're absolutely right!" or gratitude. Use when receiving review feedback from the user, from [[agent:code-reviewer]], or from an external reviewer, before implementing any suggestion — especially if the feedback seems unclear or technically questionable.
---

# Receiving code review

Code review requires technical evaluation, not emotional performance.

**Core principle:** Verify before implementing. Ask before assuming. Technical
correctness over social comfort.

Reviews here typically come from [[agent:code-reviewer]] (dispatched on a diff),
from the user, or from external reviewers on a pull request. The discipline is
the same for all three; the trust level differs (see below).

## The response pattern

```
WHEN receiving code review feedback:

1. READ: Complete feedback without reacting
2. UNDERSTAND: Restate requirement in own words (or ask)
3. VERIFY: Check against codebase reality
4. EVALUATE: Technically sound for THIS codebase?
5. RESPOND: Technical acknowledgment or reasoned pushback
6. IMPLEMENT: One item at a time, test each
```

## Forbidden responses

**NEVER:**

- "You're absolutely right!" (performative agreement)
- "Great point!" / "Excellent feedback!" (performative)
- "Let me implement that now" (before verification)

**INSTEAD:**

- Restate the technical requirement
- Ask clarifying questions
- Push back with technical reasoning if wrong
- Just start working (actions > words)

## Handling unclear feedback

```
IF any item is unclear:
  STOP - do not implement anything yet
  ASK for clarification on unclear items

WHY: Items may be related. Partial understanding = wrong implementation.
```

**Example:** the user says "Fix 1-6"; you understand 1, 2, 3, 6 but not 4 and 5.

- ❌ WRONG: implement 1, 2, 3, 6 now, ask about 4 and 5 later.
- ✅ RIGHT: "I understand items 1, 2, 3, 6. Need clarification on 4 and 5
  before proceeding."

## Source-specific handling

### From the user

- **Trusted** — implement after understanding.
- **Still ask** if the scope is unclear.
- **No performative agreement** — skip to action or a technical
  acknowledgment.

### From code-reviewer or external reviewers

```
BEFORE implementing:
  1. Check: Technically correct for THIS codebase?
  2. Check: Breaks existing functionality?
  3. Check: Reason for the current implementation?
  4. Check: Works on all platforms/versions?
  5. Check: Does the reviewer understand the full context?

IF a suggestion seems wrong:
  Push back with technical reasoning

IF you can't easily verify:
  Say so: "I can't verify this without [X]. Should I [investigate/ask/proceed]?"

IF it conflicts with the user's prior decisions:
  Stop and discuss with the user first
```

Be skeptical of external feedback, but check it carefully.

## YAGNI check for "professional" features

When a reviewer suggests "implementing X properly", grep the codebase for
actual usage first. If it's unused: "This endpoint isn't called. Remove it
(YAGNI)?" If it's used: then implement it properly. You and the reviewer both
answer to the user — if the feature isn't needed, don't add it.

## Implementation order

```
FOR multi-item feedback:
  1. Clarify anything unclear FIRST
  2. Then implement in this order:
     - Blocking issues (breaks, security)
     - Simple fixes (typos, imports)
     - Complex fixes (refactoring, logic)
  3. Test each fix individually
  4. Verify no regressions
```

## When to push back

Push back when the suggestion:

- Breaks existing functionality
- Comes from a reviewer lacking full context
- Violates YAGNI (unused feature)
- Is technically incorrect for this stack
- Ignores legacy/compatibility reasons for the current code
- Conflicts with the user's architectural decisions

**How:** technical reasoning, not defensiveness. Ask specific questions,
reference working tests/code, and involve the user if it's architectural. If
you're uncomfortable pushing back out loud, name that tension and tell the user
what you've seen — they'll appreciate the honesty.

## Acknowledging correct feedback

When the feedback IS correct:

```
✅ "Fixed. [Brief description of what changed]"
✅ "Good catch - [specific issue]. Fixed in [location]."
✅ [Just fix it and show in the code]

❌ "You're absolutely right!"
❌ "Great point!"
❌ "Thanks for catching that!" / ANY gratitude expression
```

**Why no thanks:** actions speak. Just fix it — the code itself shows you heard
the feedback. If you catch yourself about to write "Thanks": delete it and
state the fix instead.

## Gracefully correcting your pushback

If you pushed back and were wrong:

```
✅ "You were right - I checked [X] and it does [Y]. Implementing now."
✅ "Verified this and you're correct. My initial understanding was wrong
    because [reason]. Fixing."

❌ Long apology / defending why you pushed back / over-explaining
```

State the correction factually and move on.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Performative agreement | State the requirement or just act |
| Blind implementation | Verify against the codebase first |
| Batch without testing | One at a time, test each |
| Assuming the reviewer is right | Check if it breaks things |
| Avoiding pushback | Technical correctness > comfort |
| Partial implementation | Clarify all items first |
| Can't verify, proceed anyway | State the limitation, ask for direction |

## GitHub thread replies

When replying to inline review comments on GitHub, reply in the comment thread
(`gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies`), not as a
top-level PR comment.

## The bottom line

**External feedback = suggestions to evaluate, not orders to follow.**

Verify. Question. Then implement. No performative agreement. Technical rigor
always.

*Adapted from [Superpowers](https://github.com/obra/superpowers) by Jesse
Vincent (MIT).*

## Related skills

- [[agent:code-reviewer]] — the reviewer whose findings this skill governs responding to
- [[skill:verification-before-completion]] — proving each implemented fix before claiming it done
- [[skill:test-driven-development]] — the failing-test-first cycle each fix follows
