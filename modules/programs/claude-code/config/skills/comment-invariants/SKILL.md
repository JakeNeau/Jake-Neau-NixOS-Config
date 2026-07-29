---
name: comment-invariants
description: Shapes comments for invariants and constraints by naming what must remain true and the dependency or consequence that makes the condition important. Use after [[skill:comments]] classifies an added, modified, or reviewed comment as an invariant or constraint.
---

# Invariants and constraints

Name the condition and why it matters. Replace vague warnings such as “important”
or “do not change” with the concrete dependency or consequence.

## Examples

```ts
// Keep sorted.
entries.sort(compareKeys);
```

Rewrite the dependency:

```ts
// binary search requires key order
entries.sort(compareKeys);
```

```sh
# keep the rename last so readers never observe a partial file
mv "$tmp" "$settings"
```

This is a valid invariant with its consequence.

```rust
// There can only be one writer.
let _guard = writer_lock.lock();
```

Rewrite what failure causes:

```rust
// concurrent writers can lose updates
let _guard = writer_lock.lock();
```

```python
# Important: don't remove this check.
if token.expired():
    reject(token)
```

Delete the warning when `expired` and `reject` already express the complete
condition and consequence.

## Related skills

- [[skill:comments]] — supplies the shared rules and classification workflow.
- [[skill:comment-intent-rationale]] — applies to choices that are not invariants.
