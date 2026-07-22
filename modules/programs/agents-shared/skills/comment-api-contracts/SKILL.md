---
name: comment-api-contracts
description: Shapes public API and contract documentation around caller-visible behavior missing from the signature, including units, ownership, lifecycle, side effects, errors, ordering, and edge cases. Use after [[skill:comments]] classifies an added, modified, or reviewed comment as API or contract documentation.
---

# API and contract documentation

Tell callers what they need that the signature does not. Unlike ordinary
why-comments, a contract may describe what an API does, but it must not repeat
names or types. Use only the space needed to state the caller-visible contract.

## Examples

```rust
/// Gets a user by ID.
fn user(id: UserId) -> User
```

Delete the documentation when the signature is the complete contract.

```ts
/** Maximum wait in milliseconds; zero disables the deadline. */
timeout: number;
```

This valid contract adds units and zero-value behavior.

```python
def borrow_connection() -> Connection:
    """Return a pooled connection that the caller must release."""
```

This valid contract states ownership and lifecycle.

```rust
/// Parses the file.
fn parse(path: &Path) -> Result<Config, Error>
```

Replace narration with caller-visible behavior:

```rust
/// Leaves environment references unresolved for the caller.
fn parse(path: &Path) -> Result<Config, Error>
```

## Related skills

- [[skill:comments]] — supplies the shared rules and classification workflow.
- [[skill:comment-redundant-narration]] — removes signature restatement.
