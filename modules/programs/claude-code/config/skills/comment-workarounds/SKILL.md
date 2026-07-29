---
name: comment-workarounds
description: Shapes workaround and compatibility comments around the external limitation, the reason surprising code remains necessary, and a durable removal condition when known, without reciting transient error text. Use after [[skill:comments]] classifies an added, modified, or reviewed comment as a workaround.
---

# Workarounds and compatibility

Name the external constraint and why the code remains necessary. Add a durable
removal condition when known. Do not quote an error unless it alone prevents an
otherwise likely bad revert.

## Examples

```nix
# Work around a build issue.
doCheck = false;
```

Rewrite with the limitation and removal condition:

```nix
# sandboxed tests require writable /tmp; remove after nixpkgs#12345
doCheck = false;
```

```ts
// Safari ignores focus until the dialog has painted
requestAnimationFrame(() => input.focus());
```

This valid one-line comment explains the surprising delay.

```python
# Prevents "unsupported protocol version."
client.protocol = 2
```

Replace the transient error with the durable constraint:

```python
# the legacy peer accepts protocol v2 only
client.protocol = 2
```

```rust
// Temporary workaround; remove later.
retry_legacy_path();
```

Reject this wording: it identifies neither the limitation nor an actionable
removal condition.

## Related skills

- [[skill:comments]] — supplies the shared rules and classification workflow.
- [[skill:comment-task-markers]] — routes a separate deferred cleanup item.
