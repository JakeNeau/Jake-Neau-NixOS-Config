---
name: writing-pi-extensions
description: How to create and change Pi TypeScript extensions declaratively in this Nix configuration, including lifecycle events, tools, commands, testing, and deciding whether a durable resource introduced by an extension needs a new typed-link kind and adapter. Use before creating, editing, or reviewing any Pi extension.
---

# Writing Pi extensions

Pi extensions are TypeScript modules managed from
`modules/programs/pi/extensions/` in the Nix configuration and installed by
`modules/programs/pi/pi.nix`. Never edit `~/.pi/agent/extensions/` directly.
See [[skill:machine-layout]] for the configuration root on the current system.

## Read Pi's extension contract first

Resolve the installed documentation root with:

```bash
pi_store=$(dirname "$(dirname "$(realpath "$(command -v pi)")")")
pi_root="$pi_store/libexec/pi"
```

Read all of `$pi_root/docs/extensions.md`, then read only the examples under
`$pi_root/examples/extensions/` that match the APIs being used. Follow links to
other Pi documentation when the extension contract points to them.

Keep one responsibility per extension. Start background resources only from
`session_start` or the action that needs them, clean them up idempotently in
`session_shutdown`, and use `CONFIG_DIR_NAME` for project-local paths.

## Typed-resource gate

Ask whether the extension introduces a durable, reusable resource that agents
should navigate by name.

- If no, add no link type. Ordinary tools and internal modules are not resource
  kinds.
- If yes, define its `[[type:name]]` form, discovery roots, canonical naming,
  registry metadata, adapter behavior, validation, and tests before implementing
  the extension.
- Never add a type without its adapter. If the adapter is deliberately deferred,
  record it in the repository's root `TODO.md` and make traversal report it as
  unsupported.

## Validation

Write tests before production code and run them through Nix. Then run
`nix flake check` and dry-build or evaluate all Pi homes without activating any
home. Never invoke `hr`, `nr`, `nrr`, or a switch command.

## Related skills

- [[skill:using-skills]] — progressive disclosure and typed-link traversal
- [[skill:writing-skills]] — authoring skills that document extensions
- [[skill:machine-layout]] — locating and validating the Nix-managed source
