---
name: comment-intent-rationale
description: Shapes comments that explain a non-obvious design choice into the shortest durable reason without narrating mechanics, leaking downstream consumers, or preserving incidental history. Use after [[skill:comments]] classifies an added, modified, or reviewed comment as intent or rationale.
---

# Intent and rationale

State why the choice exists. Prefer one durable line beside the decision; use no
comment when names and surrounding code already make the reason clear.

## Examples

```ts
// Filter users.
const recipients = users.filter((user) => user.enabled);
```

Rewrite the reason:

```ts
// disabled users must never receive notifications
const recipients = users.filter((user) => user.enabled);
```

```nix
# preserve the upstream binary-cache hit
neovim = inputs.nvf.packages.${system}.default;
```

This earns its line because the package source looks otherwise interchangeable.

```sh
# replace atomically so interruption cannot truncate live settings
mv "$tmp" "$settings"
```

This states the reason rather than narrating the move.

```ts
// 30s timeout because the checkout dashboard polls every minute
const cacheTtl = 30_000;
```

In a reusable module that does not depend on that dashboard, remove the leaked
consumer:

```ts
// keep values younger than the minimum supported polling interval
const cacheTtl = 30_000;
```

## Related skills

- [[skill:comments]] — supplies the shared rules and classification workflow.
- [[skill:comment-invariants]] — applies when the reason is a condition that must hold.
