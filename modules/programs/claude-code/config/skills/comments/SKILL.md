---
name: comments
description: The house style for code comments in any language — why-not-what intent over restatement, ruthless concision, placement above (never below) the code, keeping each comment next to the exact line it explains (splitting big block comments and moving the pieces down), dashed-rule section labels, and referencing another file only when the file actually depends on it. Use when writing, placing, reviewing, or enforcing comments in any codebase, or deciding whether a comment earns its place and where it belongs.
---

# Comment style

The single source of truth for how comments are written and placed here. The
[[agent:comment-writer]] adds comments to this style and the
[[agent:comment-style-enforcer]] conforms existing comments to it.

# ------------
# Principles
# ------------

## Why, not what

A good comment explains the non-obvious *why*: the intent, a constraint, a
gotcha, a reason the code looks surprising. Delete any comment that merely
restates what the code already says.

## Earn the line

Add a comment only where it genuinely helps a competent reader. Obvious code
needs none; noise is worse than silence. If you can't name a non-obvious why,
write nothing.

## Concision

The shortest wording that stays useful. No multi-line preambles, hedging, or
filler — a terse line or trailing note usually suffices.

## Placement

Multi-line comments go *above* the code they describe, never below. Terse
same-line comments naming what something does and why are fine.

## Keep comments next to what they describe

A comment belongs as close as reasonable to the exact code it explains.
Proximity beats centralization: break up a block comment that covers several
steps and move each piece down to the line it explains, rather than narrating
the whole unit from the top. Keep a comment high-level only when it genuinely
spans the whole unit below it — a dashed-rule section label, or a one-line
summary of a function's contract.

## Reference only real dependencies

A comment may name another file, module, or symbol only if the file actually
depends on it — check the file's intended dependencies (its imports/uses)
first, and never reference a file it does not depend on. A reusable module does
not depend on its callers, so it must not name its specific consumers (a
particular caller, service, screen, or end user); describe its own contract,
not who happens to use it. This also forbids citing unrelated or downstream
files.

## Section labels

Group a file's logical parts with a section label fenced in dashed rules, in the
file's own comment syntax:

    # ------------
    # Section name
    # ------------

Don't over-segment — a handful of meaningful sections beats a label every few
lines.

# ------------
# Examples
# ------------

- What → why:
  - `// increment i` → *(delete)*
  - `// loop over the users` → `// skip disabled users so they never get paged`
- Concision:
  - `// We do this here because otherwise the cache might be stale, which would`
    `// cause problems for anything reading it afterwards`
    → `// refresh first: the cache may be stale`
- Reference only real dependencies (leaked consumer in a generic library):
  - `// 30s timeout — the checkout dashboard polls this every minute`
    → `// 30s timeout: callers should poll no faster than once a minute`
- Proximity (split a top-of-function block into per-step comments):

      // Validate the input, normalize the path, then write the file and
      // return its size for the caller to log.
      check(input);
      const p = normalize(input.path);
      write(p, input.data);
      return size(p);

  →

      check(input);
      // canonicalize so callers can pass relative paths
      const p = normalize(input.path);
      write(p, input.data);
      return size(p); // size lets the caller log the bytes written

# ------------
# Related skills
# ------------

- [[agent:comment-writer]] — adds comments to this style.
- [[agent:comment-style-enforcer]] — conforms existing comments to this style.
- [[skill:diataxis]] — the parallel architecture for prose documentation.
