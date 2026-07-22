---
name: comment-disabled-code
description: Removes source code hidden in comments because version control retains history, while preserving intentional examples or reference snippets governed by surrounding documentation. Use after [[skill:comments]] classifies an added, modified, or reviewed comment as commented-out code.
---

# Commented-out code

Delete it. Do not keep old implementations, debug statements, or alternatives as
comments; version control already preserves them. Intentional documentation
examples are not disabled code and follow their surrounding contract.

## Examples

```ts
// sendLegacyRequest(payload);
sendRequest(payload);
```

Delete the commented-out call.

```python
# if debug:
#     print(response)
```

Delete it; use real debug logging or version history.

```rust
// let result = old_parser.parse(input);
let result = parser.parse(input);
```

Delete the old implementation without adding a historical explanation.

```rust
/// ```
/// let client = Client::new();
/// client.connect()?;
/// ```
```

Keep this when it is a caller-facing usage example, then review it as API
contract documentation rather than disabled code.

## Related skills

- [[skill:comments]] — supplies the shared rules and classification workflow.
- [[skill:comment-api-contracts]] — governs intentional caller-facing examples.
