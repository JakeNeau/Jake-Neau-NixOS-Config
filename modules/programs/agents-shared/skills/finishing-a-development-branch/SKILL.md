---
name: finishing-a-development-branch
description: How to complete work on a development branch — verify the tests pass first, detect whether you're in a normal checkout or a linked worktree, then present exactly three structured options (merge locally, keep the branch as-is, or discard with typed confirmation) and execute the choice, cleaning up any worktree this workflow created. Pushing or opening a pull request happens only when the user explicitly asks — never offer or do it unprompted. Use when implementation on a branch is complete, all tests pass, and it's time to decide how the work integrates.
---

# Finishing a development branch

Guide completion of development work by presenting clear options and handling
the chosen workflow.

**Core principle:** Verify tests → detect environment → present options →
execute choice → clean up.

**Never push or open a pull request unprompted.** Those actions are
outward-facing; they happen only when the user explicitly asks for them.

## The process

### Step 1: verify tests

**Before presenting options, verify the tests pass** (run the project's suite:
`npm test` / `cargo test` / `pytest` / `go test ./...`).

**If tests fail:** show the failures and stop — the work can't be merged or
kept as "complete" until they pass. Don't proceed to Step 2. See
[[skill:verification-before-completion]]: evidence, never "should pass".

**If tests pass:** continue.

### Step 2: detect environment

Determine the workspace state before presenting options:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

| State | Menu | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 3 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 3 options | Provenance-based (see Step 5) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 2 options (no merge) | No cleanup (externally managed) |

### Step 3: determine the base branch

```bash
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main — is that correct?"

### Step 4: present options

**Normal repo and named-branch worktree — present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Keep the branch as-is (I'll handle it later)
3. Discard this work

Which option?
```

**Detached HEAD — present exactly these 2 options:**

```
Implementation complete. You're on a detached HEAD (externally managed
workspace).

1. Keep as-is (I'll handle it later)
2. Discard this work

Which option?
```

**Don't add explanation** — keep the options concise. Don't offer push/PR; if
the user asks for one, that's their explicit request — do it then (push with
`git push -u origin <branch>` and keep the worktree alive for iteration).

#### Option 1: merge locally

```bash
# Get main repo root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first — verify success before removing anything
git checkout <base-branch>
git pull
git merge <feature-branch>

# Verify tests on the merged result
<test command>
```

Only after the merge succeeds: clean up the worktree (Step 5), then delete the
branch with `git branch -d <feature-branch>`.

#### Option 2: keep as-is

Report: "Keeping branch <name>. Worktree preserved at <path>." **Don't clean up
the worktree.**

#### Option 3: discard

**Confirm first:**

```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for the exact confirmation. If confirmed, `cd` to the main repo root (as
in Option 1), clean up the worktree (Step 5), then force-delete the branch with
`git branch -D <feature-branch>`.

### Step 5: clean up the workspace

**Only runs for Options 1 and 3.** Option 2 always preserves the worktree.

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

**If `GIT_DIR == GIT_COMMON`:** normal repo, no worktree to clean up. Done.

**If the worktree path is under `.worktrees/` or `worktrees/`:** this workflow
created it (see the isolation section of [[skill:git]]) — we own cleanup:

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**Otherwise:** the host environment (harness) owns this workspace. Do NOT
remove it — use the platform's workspace-exit tool if one exists, or leave it
in place.

## Quick reference

| Option | Merge | Keep worktree | Cleanup branch |
|--------|-------|---------------|----------------|
| 1. Merge locally | yes | - | yes |
| 2. Keep as-is | - | yes | - |
| 3. Discard | - | - | yes (force) |

## Common mistakes

- **Skipping test verification** — you merge broken code. Always verify tests
  before offering options.
- **Open-ended questions** — "What should I do next?" is ambiguous. Present
  exactly 3 structured options (or 2 for detached HEAD).
- **Offering to push or PR** — outward-facing actions are the user's call;
  wait for an explicit request.
- **Deleting the branch before removing the worktree** — `git branch -d` fails
  while a worktree still references the branch. Merge, remove the worktree,
  then delete the branch.
- **Running `git worktree remove` from inside the worktree** — fails when CWD
  is inside it. Always `cd` to the main repo root first.
- **Cleaning up harness-owned worktrees** — removing a worktree the harness
  created causes phantom state. Only clean up worktrees under `.worktrees/` or
  `worktrees/`.
- **No confirmation for discard** — accidental deletion of work. Require the
  typed "discard" confirmation.

## Red flags

**Never:**

- Proceed with failing tests
- Merge without verifying tests on the result
- Delete work without confirmation
- Push, force-push, or open a PR without an explicit request
- Remove a worktree before confirming merge success
- Clean up worktrees you didn't create (provenance check)
- Run `git worktree remove` from inside the worktree

**Always:**

- Verify tests before offering options
- Detect the environment before presenting the menu
- Present exactly 3 options (or 2 for detached HEAD)
- Get typed confirmation for discard
- Clean up the worktree for Options 1 and 3 only
- `cd` to the main repo root before worktree removal
- Run `git worktree prune` after removal

*Adapted from [Superpowers](https://github.com/obra/superpowers) by Jesse
Vincent (MIT).*

## Related skills

- [[skill:git]] — branch/commit conventions and the worktree isolation this cleans up
- [[skill:jujutsu]] — the jj equivalent (workspaces instead of worktrees)
- [[skill:verification-before-completion]] — the evidence gate behind Step 1
