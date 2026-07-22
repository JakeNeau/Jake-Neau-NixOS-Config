---
name: comment-structural-markers
description: Governs structural comments such as dashed-rule section labels, meaningful algorithm phases, and Given/When/Then test markers while preventing labels from narrating every small block. Use after [[skill:comments]] classifies an added, modified, or reviewed comment as a structural marker.
---

# Structural markers

Use markers only where they provide a real map of a file, long function, or
test. A handful of meaningful boundaries beats a label for every operation.

## Examples

```nix
# ------------
# Registry construction
# ------------
```

This is a valid section label for a substantial logical part.

```ts
// Given
const account = disabledAccount();
// When
const result = notify(account);
// Then
expect(result).toEqual("skipped");
```

These sanctioned test phases may remain even though they describe structure.

```ts
// Validate
validate(input);
// Transform
transform(input);
// Return
return input;
```

Delete all three labels from a short linear function.

```python
# Handle data
```

Replace a vague section name with a concrete logical boundary, or delete it if
no substantial section follows.

## Related skills

- [[skill:comments]] — supplies the shared rules and classification workflow.
- [[skill:comment-redundant-narration]] — removes operation-by-operation labels.
