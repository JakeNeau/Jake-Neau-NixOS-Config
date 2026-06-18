---
name: configuring-plugins
description: How to install a Claude Code plugin (from a marketplace) in this repo. Plugins are a hybrid — a declarative `enabledPlugins` entry in the `settingsPolicy` attrset in claude-code.nix records intent and survives rebuilds, but Claude Code never auto-fetches plugins from settings, so the runtime cache is also populated once per machine with `claude plugin install`. Covers official vs third-party marketplaces, the enabledPlugins / extraKnownMarketplaces schema, why a pure-declarative install is impossible today, and disabling/removing. Use when adding, enabling, disabling, or removing a Claude Code plugin or marketplace (e.g. Superpowers) globally.
---

# Configuring plugins

A Claude Code **plugin** bundles skills, agents, commands, hooks, and MCP/LSP
servers from a marketplace. Installing one here is a **hybrid**, because Claude
Code never auto-fetches plugins from declarative settings — settings only record
intent (upstream feature requests anthropics/claude-code #45323, #23737):

1. **Declarative intent** (in the flake, propagates to every machine) — an
   `enabledPlugins` entry in the `settingsPolicy` attrset.
2. **Cache population** (once per machine) — `claude plugin install …`, which
   fetches the plugin into `~/.claude/plugins/cache/` (runtime state, not
   Nix-pinned).

Skip either and it won't load: no entry → not enabled after a settings reset or on
your other machines; no install → enabled-but-missing on this one.

## Where it goes — edit Nix, not a file

Like LSP/MCP this is **not** a file under `config/` — it's a **Nix attrset**. Add
the entry to **`settingsPolicy`** in
`modules/programs/claude-code/claude-code.nix`. That attrset is deep-merged into
the live `~/.claude/settings.json` by the `home.activation.claudeCodeSettingsPolicy`
jq step (`. * $policy`, our keys win), so the plugin stays enabled across rebuilds
and other plugin keys are preserved.

## Steps

1. **Add the enabledPlugins entry** — the key is `"<plugin>@<marketplace>"`:

   ```nix
   # official marketplace (auto-registered — no marketplace entry needed)
   settingsPolicy.enabledPlugins."superpowers@claude-plugins-official" = true;
   ```

2. **Third-party marketplace only** — also register it via `extraKnownMarketplaces`:

   ```nix
   settingsPolicy.enabledPlugins."foo@my-org" = true;
   settingsPolicy.extraKnownMarketplaces.my-org = {
     source = {source = "github"; repo = "my-org/claude-plugins";};
     autoUpdate = false;
   };
   ```

3. **`git add`** the file, then let the user rebuild (see [[claude-code-config]]).

4. **Populate the cache — once per machine.** Needs network and writes under
   `~/.claude`, so it fails sandboxed (`EPERM`); run it with the sandbox disabled:

   ```sh
   claude plugin install <plugin>@<marketplace> --scope user
   ```
   Then `/reload-plugins` (or restart) to activate it in a running session.

## Disable or remove

- **Disable:** set the entry to `false` (or delete it) and rebuild. The activation
  merge force-applies whatever the policy says, so a live `/plugin disable` is
  re-enabled on the next rebuild unless the Nix entry changes too.
- **Remove fully:** delete the entry, rebuild, then `claude plugin uninstall
  <plugin>@<marketplace>` on each machine to clear the cache.

## Why / gotchas

- The official marketplace `claude-plugins-official` is auto-registered, so plugins
  in it need only `enabledPlugins`, never `extraKnownMarketplaces`.
- Plugins run arbitrary code with your privileges and spend context every turn
  (their skill/agent/MCP schemas) — vet the source and enable only what you need.
- Plugin skills and commands are namespaced: a plugin `foo` exposes `/foo:<name>`.

## Reference

- Install & marketplaces: https://code.claude.com/docs/en/discover-plugins
- Settings schema (`enabledPlugins`, `extraKnownMarketplaces`): https://code.claude.com/docs/en/settings

## Related skills

- [[claude-code-config]] — the declarative edit/ship workflow and where config lives
- [[configuring-mcp-servers]] — sibling Nix-attrset config (a plugin can bundle MCP servers)
- [[machine-layout]] — the Nix machine context and rebuild flow
