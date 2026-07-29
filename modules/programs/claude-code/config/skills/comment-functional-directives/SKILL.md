---
name: comment-functional-directives
description: Protects machine-readable comment directives for linters, compilers, formatters, coverage tools, and similar processors from prose styling or accidental syntax changes. Use after [[skill:comments]] classifies an added, modified, or reviewed comment as a functional directive.
---

# Functional directives

Preserve the processor-required syntax exactly. Classify any adjacent human
rationale separately; never beautify a directive as prose.

## Examples

```ts
// eslint-disable-next-line @typescript-eslint/no-explicit-any
```

Preserve it verbatim.

```sh
# shellcheck disable=SC2086
run $args
```

Preserve the directive. Add separate rationale only if intentional word
splitting is surprising and not evident locally.

```python
value = expression  # noqa: E501
```

Do not rewrite `noqa` or alter its code list for style.

```ts
// Ignore the explicit-any lint rule on the next line.
```

Delete this narration; it is not a substitute for the required directive.

## Related skills

- [[skill:comments]] — supplies the shared rules and classifies adjacent prose.
- [[skill:comment-intent-rationale]] — governs a separate human reason for a directive.
