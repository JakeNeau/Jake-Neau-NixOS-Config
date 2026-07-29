---
name: comment-redundant-narration
description: Identifies comments that merely restate adjacent code, names, types, or signatures and removes them instead of paraphrasing the same information. Use after [[skill:comments]] classifies an added, modified, or reviewed comment as redundant narration.
---

# Redundant narration

Delete the comment. Do not rescue it with synonyms. If it mixes narration with a
useful reason, keep only the reason and classify that remainder separately.

## Examples

```ts
// Increment the retry count.
retryCount++;
```

Delete the comment.

```nix
# Enable Firefox.
programs.firefox.enable = true;
```

Delete the comment.

```rust
/// Returns the user ID.
fn user_id(&self) -> UserId
```

Delete the documentation when the signature is the complete contract.

```sh
# Create the directory before writing because fresh installs lack it.
mkdir -p "$config_dir"
```

Keep only the reason:

```sh
# fresh installs lack the config directory
mkdir -p "$config_dir"
```

## Related skills

- [[skill:comments]] — supplies the shared rules and classification workflow.
- [[skill:comment-intent-rationale]] — governs a useful reason recovered from narration.
