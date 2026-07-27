---
name: systematic-debugging
description: The discipline for fixing any bug, test failure, or unexpected behavior — no fixes without root-cause investigation first. Four mandatory phases (root cause, pattern analysis, hypothesis testing, implementation), a rationalization table for the excuses that tempt you to skip them, and a circuit breaker — three failed fixes means question the architecture, not attempt a fourth. Folds in root-cause tracing, defense-in-depth validation, and condition-based waiting. Use when encountering any bug, test failure, build failure, or unexpected behavior, before proposing any fix — especially under time pressure or after a previous fix didn't work.
---

# Systematic debugging

Random fixes waste time and create new bugs. Quick patches mask underlying
issues.

**Core principle:** ALWAYS find the root cause before attempting fixes. Symptom
fixes are failure.

**Violating the letter of this process is violating the spirit of debugging.**

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

## When to use

Use for ANY technical issue: test failures, bugs in production, unexpected
behavior, performance problems, build failures, integration issues.

**Use this ESPECIALLY when:**

- Under time pressure (emergencies make guessing tempting)
- "Just one quick fix" seems obvious
- You've already tried multiple fixes
- The previous fix didn't work
- You don't fully understand the issue

**Don't skip when:**

- The issue seems simple (simple bugs have root causes too)
- You're in a hurry (rushing guarantees rework)
- The user wants it fixed NOW (systematic is faster than thrashing)

## The four phases

You MUST complete each phase before proceeding to the next.

### Phase 1: root cause investigation

**BEFORE attempting ANY fix:**

1. **Consult the project docs first** — before tracing any code, read the
   documentation for the high-level flow of the affected area, per
   [[skill:documentation]] (dispatch [[agent:doc-reader]] or read the docs tree
   directly). Code is for low-level detail; if the docs should have covered the
   flow and didn't, note the gap for Phase 4's capture step.
2. **Read error messages carefully** — don't skip past errors or warnings; they
   often contain the exact solution. Read stack traces completely; note line
   numbers, file paths, error codes.
3. **Reproduce consistently** — can you trigger it reliably? What are the exact
   steps? If not reproducible → gather more data, don't guess.
4. **Check recent changes** — what changed that could cause this? Git diff,
   recent commits, new dependencies, config changes, environmental differences.
5. **Gather evidence in multi-component systems** — when the system has multiple
   components (CI → build → signing, API → service → database), add diagnostic
   instrumentation at EACH component boundary before proposing fixes: log what
   data enters and exits each component, verify environment/config propagation,
   check state at each layer. Run once to see WHERE it breaks, then investigate
   that specific component.
6. **Trace data flow backward to the source.** When the error is deep in the
   call stack, don't fix where it appears — that's a symptom. Ask: where does
   the bad value originate? What called this with the bad value? Keep tracing up
   the chain, one caller at a time, until you find the original trigger, and fix
   there. When you can't trace manually, instrument: log the suspect value plus
   `cwd`/env and a captured stack trace immediately before the failing
   operation, run once, and read the chain off the output.

### Phase 2: pattern analysis

**Find the pattern before fixing:**

1. **Find working examples** — locate similar working code in the same
   codebase. What works that's similar to what's broken?
2. **Compare against references** — if implementing a pattern, read the
   reference implementation COMPLETELY. Don't skim; understand it fully before
   applying it.
3. **Identify differences** — list every difference between working and broken,
   however small. Don't assume "that can't matter".
4. **Understand dependencies** — what other components, settings, config, and
   assumptions does this need?

### Phase 3: hypothesis and testing

**Scientific method:**

1. **Form a single hypothesis** — state clearly: "I think X is the root cause
   because Y." Be specific, not vague.
2. **Test minimally** — make the SMALLEST possible change to test the
   hypothesis. One variable at a time; don't fix multiple things at once.
3. **Verify before continuing** — did it work? Yes → Phase 4. No → form a NEW
   hypothesis. DON'T add more fixes on top.
4. **When you don't know** — say "I don't understand X". Don't pretend to know;
   ask for help or research more.

### Phase 4: implementation

**Fix the root cause, not the symptom:**

1. **Create a failing test case** — simplest possible reproduction, automated if
   possible. MUST exist before fixing. Use
   [[skill:test-driven-development]] for writing proper failing tests.
2. **Implement a single fix** — address the root cause identified. ONE change at
   a time. No "while I'm here" improvements, no bundled refactoring.
3. **Verify the fix** — test passes now? No other tests broken? Issue actually
   resolved?
4. **If the fix doesn't work** — STOP. Count: how many fixes have you tried? If
   fewer than 3, return to Phase 1 and re-analyze with the new information. **If
   3 or more: STOP and question the architecture (below).** Don't attempt fix #4
   without an architectural discussion.
5. **If 3+ fixes failed: question the architecture.** The telltale pattern: each
   fix reveals a new shared-state/coupling problem somewhere else, fixes require
   "massive refactoring", each fix creates new symptoms. STOP and ask: is this
   pattern fundamentally sound? Are we sticking with it through sheer inertia?
   Should we refactor the architecture instead of continuing to fix symptoms?
   **Discuss with the user before attempting more fixes.** This is NOT a failed
   hypothesis — this is a wrong architecture.
6. **Capture documentation gaps** — once the fix is verified, run
   [[skill:documentation]]'s capture flow: surface any reference gaps (you
   needed code for a high-level flow) and how-to gaps (you discovered a
   generally applicable procedure) hit along the way, and ask the user whether
   to update the docs.

## Red flags — STOP and follow the process

If you catch yourself thinking:

- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "Add multiple changes, run tests"
- "Skip the test, I'll manually verify"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- "Pattern says X but I'll adapt it differently"
- "Here are the main problems: [lists fixes without investigation]"
- Proposing solutions before tracing data flow
- **"One more fix attempt" (when already tried 2+)**
- **Each fix reveals a new problem in a different place**

**ALL of these mean: STOP. Return to Phase 1.**

## Signals from the user that you're doing it wrong

- "Is that not happening?" — you assumed without verifying
- "Will it show us...?" — you should have added evidence gathering
- "Stop guessing" — you're proposing fixes without understanding
- "We're stuck?" (frustrated) — your approach isn't working

**When you see these:** STOP. Return to Phase 1.

## Common rationalizations

| Excuse | Reality |
|--------|---------|
| "Issue is simple, don't need process" | Simple issues have root causes too. The process is fast for simple bugs. |
| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check thrashing. |
| "Just try this first, then investigate" | The first fix sets the pattern. Do it right from the start. |
| "I'll write the test after confirming the fix works" | Untested fixes don't stick. Test first proves it. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
| "Reference too long, I'll adapt the pattern" | Partial understanding guarantees bugs. Read it completely. |
| "I see the problem, let me fix it" | Seeing symptoms ≠ understanding root cause. |
| "One more fix attempt" (after 2+ failures) | 3+ failures = architectural problem. Question the pattern, don't fix again. |

## Quick reference

| Phase | Key activities | Success criteria |
|-------|---------------|------------------|
| **1. Root cause** | Consult docs, read errors, reproduce, check changes, gather evidence | Understand WHAT and WHY |
| **2. Pattern** | Find working examples, compare | Identify differences |
| **3. Hypothesis** | Form theory, test minimally | Confirmed or new hypothesis |
| **4. Implementation** | Create test, fix, verify | Bug resolved, tests pass |

## When the process reveals "no root cause"

If systematic investigation shows the issue is truly environmental,
timing-dependent, or external: you've completed the process — document what you
investigated, implement appropriate handling (retry, timeout, error message),
and add monitoring for future investigation. **But:** 95% of "no root cause"
cases are incomplete investigation.

## Supporting techniques

- **Defense-in-depth validation.** After fixing at the source, validate at
  EVERY layer the bad data passes through — entry-point checks reject invalid
  input at the API boundary, business-logic checks catch what slips past,
  environment guards block context-specific dangers (e.g. refuse destructive
  operations outside a temp dir in tests), and debug logging captures forensics.
  One check says "we fixed the bug"; layered checks make it structurally
  impossible.
- **Condition-based waiting.** Flaky, timing-dependent tests should poll for the
  actual condition they care about (with a timeout) instead of sleeping an
  arbitrary duration; reserve fixed delays for genuinely timed behavior, waited
  for only after the triggering condition, with a comment justifying the number.

*Adapted from [Superpowers](https://github.com/obra/superpowers) by Jesse
Vincent (MIT).*

## Related skills

- [[skill:documentation]] — docs-first reading (Phase 1) and the gap-capture flow (Phase 4)
- [[skill:test-driven-development]] — writing the failing test that pins the bug (Phase 4)
- [[skill:verification-before-completion]] — proving the fix worked before claiming success
- [[agent:bug-finder]] — the proactive hunt for latent bugs nobody has pointed at yet
