---
name: configuring-lsp-servers
description: How to configure language servers for Claude Code in this repo — the lspServers Nix attrset in modules/programs/claude-code/claude-code.nix (NOT a file under config/), which generates ~/.claude/.lsp.json. Covers the command/args/extensionToLanguage schema, pinning binaries to Nix store paths, and mirroring the editor's LSPs. Use when adding or changing an LSP / language server Claude uses for diagnostics and navigation.
---

# Configuring LSP servers

LSP servers give Claude real-time code intelligence — diagnostics after edits,
go-to-definition, hover, find-references. Unlike agents/commands/skills, this is
**not** a file under `config/`: it is a **Nix attrset**.

## Where it goes — edit Nix, not a file

Add an entry to the `lspServers` attrset in
`modules/programs/claude-code/claude-code.nix`. The module serializes it to
`~/.claude/.lsp.json` on rebuild. Same workflow otherwise: edit → `git add` →
rebuild (see [[claude-code-config]]).

## Schema

Each entry is keyed by language name:

```nix
go = {
  command = "${pkgs.gopls}/bin/gopls";
  args = [];
  extensionToLanguage = {".go" = "go";};
};
```

- `command` — **pin to a Nix store path** (`${pkgs.<server>}/bin/...`) so it
  resolves regardless of PATH. Nix provides the binary; no separate install.
- `args` — server arguments (e.g. `["--stdio"]`, `["start"]`).
- `extensionToLanguage` — map **every** relevant extension to its language id
  (e.g. `.ts` and `.tsx`).
- Optional (upstream-supported): `env`, `transport`, `initializationOptions`,
  `settings`, `startupTimeout`, `maxRestarts`, `diagnostics`.

## Best practices

- **One entry per language**, flat structure.
- **Map all extensions** a language uses, not just the canonical one.
- **Pin absolute store paths** — never bare binary names.
- **Mirror the editor.** Keep this list in parity with the languages nvf
  configures (`modules/programs/nvf`) so Claude and the editor agree.

## Reference

Official docs (LSP server config / `.lsp.json`):
https://code.claude.com/docs/en/plugins-reference

## Related skills

- [[claude-code-config]] — the declarative edit/ship workflow
- [[machine-layout]] — where `claude-code.nix` lives and how rebuilds apply
