---
name: verification-before-completion
description: The gate before claiming any work is complete, fixed, or passing — identify the command that proves the claim, run it fresh, read the full output, and only then state the result with evidence. Includes the failure table (what each claim actually requires) and the rationalization table for "should work", "I'm confident", and "the agent said success". Use when about to claim success, express satisfaction, commit, or move to the next task — evidence before assertions, always.
---

# Verification before completion

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim
it passes.

## The gate function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

## Common failures

| Claim | Requires | Not sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |

## Red flags — STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit, push, or open a PR without verification
- Trusting agent success reports
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting the work over
- **ANY wording implying success without having run verification**

## Rationalization prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler |
| "Agent said success" | Verify independently |
| "I'm tired" | Exhaustion ≠ excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

## Key patterns

**Tests:**
```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

**Regression tests (TDD red-green):**
```
✅ Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

**Build:**
```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

**Requirements:**
```
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
❌ "Tests pass, phase complete"
```

**Agent delegation:**
```
✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
❌ Trust agent report
```

## Why this matters

Failure memories from real sessions: the user said "I don't believe you" —
trust broken. Undefined functions shipped that would crash. Missing
requirements shipped as incomplete features. Time wasted on false completion,
then redirection and rework. Honesty is a core value.

## When to apply

**ALWAYS before:**

- ANY variation of a success/completion claim
- ANY expression of satisfaction
- ANY positive statement about the work's state
- Committing, creating a PR (when the user asked for one), task completion
- Moving to the next task
- Delegating to agents

**The rule applies to:** exact phrases, paraphrases and synonyms, implications
of success — ANY communication suggesting completion or correctness.

## The bottom line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.

*Adapted from [Superpowers](https://github.com/obra/superpowers) by Jesse
Vincent (MIT).*

## Related skills

- [[skill:test-driven-development]] — the red-green cycle this gate verifies
- [[skill:systematic-debugging]] — proving a fix actually resolved the symptom
- [[skill:finishing-a-development-branch]] — the tests-pass gate at branch end
- [[agent:code-reviewer]] — independent proof that a diff is correct
