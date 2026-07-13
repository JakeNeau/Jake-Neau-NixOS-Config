---
name: writing-plans
description: How to write an implementation plan rigorous enough for an engineer with zero context on the codebase — map the file structure first, break the work into bite-sized tasks with exact paths, complete code, and exact commands, forbid placeholders, and self-review the plan against the spec. The result fills the Plan and Tasks sections of the specs/ file per [[skill:specs]], and the approved plan is handed to [[agent:code-writer]] to execute. Use when a design or spec exists for a multi-step task and you need the implementation plan, before touching code.
---

# Writing plans

Write comprehensive implementation plans assuming the engineer has zero context
for our codebase and questionable taste. Document everything they need to know:
which files to touch for each task, code, testing, docs they might need to
check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI.
TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset
or problem domain. Assume they don't know good test design very well.

**Where the plan lives:** in the spec file that [[skill:brainstorming]] produced
— the plan fills the `## Plan` section and the task breakdown fills `## Tasks`
(see [[skill:specs]] for the file anatomy and lifecycle).

## Scope check

If the spec covers multiple independent subsystems, it should have been broken
into sub-project specs during brainstorming. If it wasn't, suggest breaking this
into separate plans — one per subsystem. Each plan should produce working,
testable software on its own.

## File structure

Before defining tasks, map out which files will be created or modified and what
each one is responsible for. This is where decomposition decisions get locked
in.

- Design units with clear boundaries and well-defined interfaces. Each file
  should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are
  more reliable when files are focused. Prefer smaller, focused files over large
  ones that do too much.
- Files that change together should live together. Split by responsibility, not
  by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large
  files, don't unilaterally restructure — but if a file you're modifying has
  grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce
self-contained changes that make sense independently.

## Task right-sizing

A task is the smallest unit that carries its own test cycle and is worth a fresh
reviewer's gate. When drawing task boundaries: fold setup, configuration,
scaffolding, and documentation steps into the task whose deliverable needs them;
split only where a reviewer could meaningfully reject one task while approving
its neighbor. Each task ends with an independently testable deliverable.

## Bite-sized task granularity

**Each step is one action (2-5 minutes):**

- "Write the failing test" — step
- "Run it to make sure it fails" — step
- "Implement the minimal code to make the test pass" — step
- "Run the tests and make sure they pass" — step
- "Commit" — step

## The `## Plan` header

Open the `## Plan` section with the plan's frame, before any task:

```markdown
**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech stack:** [Key technologies/libraries]

**Global constraints:** [The spec's project-wide requirements — version floors,
dependency limits, naming and copy rules, platform requirements — one line
each, with exact values copied verbatim from the spec. Every task's
requirements implicitly include this list.]
```

## Task structure

Each task in `## Tasks` follows this shape (checkboxes track progress):

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter and
  return types. A task's implementer sees only their own task; this block is
  how they learn the names and types neighboring tasks use.]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No placeholders

Every step must contain the actual content an engineer needs. These are **plan
failures** — never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out
  of order)
- Steps that describe what to do without showing how (code blocks required for
  code steps)
- References to types, functions, or methods not defined in any task

## Remember

- Exact file paths always.
- Complete code in every step — if a step changes code, show the code.
- Exact commands with expected output.
- DRY, YAGNI, TDD, frequent commits.

## Self-review

After writing the complete plan, look at the spec with fresh eyes and check the
plan against it:

1. **Spec coverage:** skim each section/requirement in the spec. Can you point
   to a task that implements it? List any gaps.
2. **Placeholder scan:** search your plan for any of the patterns from the "No
   placeholders" section above. Fix them.
3. **Type consistency:** do the types, method signatures, and property names
   used in later tasks match what earlier tasks defined? A function called
   `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

If you find issues, fix them inline. If you find a spec requirement with no
task, add the task. Then have [[agent:plan-verifier]] adversarially verify the
plan — it checks completeness, feasibility, and grounding in the real codebase,
and returns the specific holes to fix.

## Execution handoff

Once the plan is verified and the user approves it, hand it to
[[agent:code-writer]] to implement — it executes the plan task by task,
test-first, and proves the result with [[agent:code-reviewer]].

*Adapted from [Superpowers](https://github.com/obra/superpowers) by Jesse
Vincent (MIT).*

## Related skills

- [[skill:specs]] — the file whose `## Plan` / `## Tasks` sections this skill fills
- [[skill:brainstorming]] — produces the approved design this plan implements
- [[skill:test-driven-development]] — the test-first cycle every task encodes
- [[agent:plan-verifier]] — adversarial verification before execution
- [[agent:code-writer]] — executes the approved plan
