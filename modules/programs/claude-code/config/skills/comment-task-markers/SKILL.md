---
name: comment-task-markers
description: Routes TODO, FIXME, and HACK comments through the current project's work-tracking convention and separates genuine deferred work from workaround rationale. Use after [[skill:comments]] classifies an added, modified, or reviewed comment as a task or debt marker.
---

# Task and debt markers

Do not invent comment-local tracking. Follow the project's tracker convention;
keep a local marker only when that convention explicitly requires one.

## Examples

```ts
// TODO: improve retries
```

Remove it and record a self-contained item in the project tracker.

```nix
# FIXME: remove later
```

Fix it now or track the exact removal condition outside the code.

```ts
// HACK: Safari ignores focus until paint.
requestAnimationFrame(() => input.focus());
```

This is rationale, not a task marker. Rewrite it under the workaround policy:

```ts
// Safari ignores focus until the dialog has painted
requestAnimationFrame(() => input.focus());
```

```python
# TODO(PROJ-417): remove after the v1 API is retired
```

Keep this only when the project's explicit convention requires tracker-backed
local markers; otherwise the tracker entry is sufficient.

## Related skills

- [[skill:comments]] — supplies the shared rules and classification workflow.
- [[skill:comment-workarounds]] — governs HACK text that actually explains compatibility code.
