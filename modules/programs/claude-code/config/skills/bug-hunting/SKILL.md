---
name: bug-hunting
description: How to hunt for latent bugs — both dispatching a hunt and running one. Dispatching means never hunting inline — scope the surface, partition anything wider than one module into 2–5 non-overlapping grounds, dispatch one bug-finder per ground all in parallel, then merge, dedupe, and re-rank the findings. Running a hunt means the methodology the bug-finder follows — the scope priority order, the hypothesis-and-adversary method with proof by execution, the five-tier CONFIRMED/PROVEN/PROBABLE/SUSPECTED/THEORETICAL confidence ladder and its honesty rules, the read-only discipline, and the output format. Use when you suspect latent bugs beyond the change at hand, want to find bugs, audit a module, check code for issues, or wonder whether some code is safe — and when you are the bug-finder running a hunt. See [[agent:bug-finder]] for the agent that runs a hunt, and [[agent:code-reviewer]] for proving a specific diff instead.
---

# Bug hunting

**Bug hunting is always delegated to [[agent:bug-finder]] — never hunted
inline.** The dispatcher (the main session, or whichever agent wants a hunt)
scopes, partitions, and merges; the bug-finder hunts. Part A is for the
dispatcher; Part B is the methodology the bug-finder itself follows.

# ------------
# Part A — Dispatching a hunt
# ------------

## Scope, then size the fan-out

- **One narrow target** — a single file, one module, a small diff — gets **one
  bug-finder**.
- **A broad surface** — several modules, a subsystem, the whole repo — gets
  **partitioned into independent hunting grounds, with one bug-finder per
  ground, all dispatched in parallel**: a single message carrying multiple
  Agent/task calls, never a sequence of one-at-a-time hunts.

## Partition into grounds

Cut along natural seams — per module, per subsystem, or per risk class (input
parsing, concurrency, error paths). Grounds must **not overlap**, so findings
don't duplicate. Typically 2–5 grounds; more than that dilutes each hunt.

Each dispatch names its ground explicitly and passes any context the headless
agent can't see — the bug-finder gets only the task text, not the conversation
that motivated the hunt.

## Merge the findings

Never dump raw per-agent output. Merge the returns:

1. **Dedupe** findings that cross ground boundaries (two hunters can reach the
   same bug from different sides).
2. **Re-rank** the union by confidence tier first, then severity.
3. **Report** the merged, ranked list as one result.

# ------------
# Part B — Running a hunt (the bug-finder's methodology)
# ------------

## Scope

Determine the hunting ground, in priority order — the same order the reviewer
uses:

1. **Explicit target.** If pointed at a file, module, or a named area ("the
   auth flow", "the parser"), that is the ground.
2. **The diff/branch.** Otherwise, if a change is the obvious context, hunt
   over it — `git diff HEAD`, else `git diff main...HEAD` (use `master` if
   there is no `main`).
3. **A broad surface.** Otherwise range widely — but risk-prioritized so you do
   not drown. Go first where bugs concentrate: input parsing, concurrency,
   error and failure paths, boundaries, and handling of external or untrusted
   data.

## Method — hypothesis and adversary

Hunt by forming adversarial hypotheses and then trying to prove them true:

1. **Map the ground.** Learn the shape of the code in scope and where its risky
   surface lies — the inputs it trusts, the state it shares, the failures it
   must handle.
2. **Enumerate adversarial hypotheses.** For each unit, ask "what input, state,
   or sequence breaks this?" — null/empty, off-by-one, races, resource leaks,
   unhandled errors, injection, contract violations. Write the candidates down.
3. **Fan out for evidence.** Dispatch parallel read-only scouts (`Explore` in
   Claude Code, `scout` in omp) to gather evidence per lead. Scouts do legwork,
   not judgment — never spawn another bug-finder or investigator.
4. **Trace each candidate.** Follow the actual path at `file:line`: from the
   input that triggers it to the point it fails.
5. **Try to refute it.** Adversarially attack your own candidate — is the path
   actually reachable? Is there an upstream guard? Does every caller prevent
   the bad input? Kill the candidate if it cannot survive the refutation
   attempt; a bug that dies here was never a bug.
6. **Prove by execution.** Attempt this for *every* surviving candidate. Write
   a repro in the scratch or tmp directory — **never** in the repo — and run
   it, using `nix run nixpkgs#<pkg>` to pull any language runtime, linter, or
   fuzzer the repro needs. Observe the actual failure. Skip execution only when
   it is provably impossible (no runnable entry point, a hardware or
   environment dependency, no way to force the failure deterministically).
7. **Assign confidence.** Rate each survivor by the strength of the evidence
   gathered, using the ladder below.

When root-causing a stubborn candidate — the failure reproduces but you cannot
explain why — work it per [[skill:systematic-debugging]]: find the root cause
before you write it up.

## Confidence ladder

Rank every finding by this ladder. Each tier is defined by exactly what
evidence it requires:

- **CONFIRMED** — reproduced by execution. A repro actually triggered the
  failure and you observed the wrong output or the crash. This is the only tier
  that requires running code.
- **PROVEN** — complete static proof. The whole path, from a reachable input to
  the failure, is traced at `file:line` with no gaps and no inference — it
  *would* fail if run — but execution was genuinely impossible or the failure
  could not be forced deterministically.
- **PROBABLE** — traced, but one inferred link. Reachable and mostly read
  firsthand, yet a single link rests on a reasoned assumption rather than code
  you actually read.
- **SUSPECTED** — a concrete failure hypothesis with partial evidence, but an
  open gap remains in reachability or the trace.
- **THEORETICAL** — a pattern smell only. Code matching a known bug class, with
  no proven-reachable triggering path — flagged for a human to judge, not shown
  to be triggerable.

Honesty rules:

- **Execution caps the tier.** Skipping execution caps a finding at PROVEN —
  nothing you did not run may claim CONFIRMED.
- **Push each finding as high as the truth allows, never higher.** Attempt the
  repro to reach CONFIRMED; read the inferred link firsthand to lift PROBABLE
  to PROVEN. But never inflate a tier to sound more certain than the evidence.
- **Name the lever.** Each finding states its tier *and* the single thing that
  would raise it — e.g. "SUSPECTED — PROVEN once the parser is shown reachable
  from untrusted input".

## Read-only discipline

The hunt is read-only on the repo. Use the shell only to inspect — `git`
diff/log/blame/show, searches, builds, running the existing tests to observe
behavior — and to run repros in the scratch or tmp directory, never a tracked
file. Calibrate effort to risk, going deepest where a bug would hurt most. Hand
a proven bug back to whichever stage owns that code — [[agent:code-writer]] for
code the flow just produced — the hunter finds and proves, it does not repair.

## Output

Lead with a one-line summary of what was hunted and the headline count by tier
(e.g. "Hunted the parser: 1 CONFIRMED, 2 SUSPECTED, 1 THEORETICAL"). Then list
the findings, ranked most-confident and most-severe first. Each finding gives:

- **Title** — what the bug is, in a phrase.
- **Location** — `file:line`.
- **Confidence** — the tier, *why* it sits there, and the one thing that would
  raise it.
- **Failure scenario** — the concrete path: this input → this wrong result or
  crash.
- **Evidence** — the traced path, and (when executed) the repro command and the
  observed output.
- **Suggested fix** — a diff sketch or a precise description of the fix.
  Described, never applied.

## Related skills

- [[skill:systematic-debugging]] — root-causing a stubborn candidate before writing it up
