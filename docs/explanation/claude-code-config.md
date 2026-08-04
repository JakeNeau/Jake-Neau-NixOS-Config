# The declarative claude-code subsystem

Why Claude Code's configuration — skills, agents, hooks, MCP servers,
sandbox policy — is managed as a subsystem of this flake
(`modules/programs/claude-code/`), and the design choices that shape it.

## The goal: one config, wherever it's used

Claude Code normally stores its configuration under `~/.claude` on each
machine. This repository stores the durable files under
`modules/programs/claude-code/config/`. The `flake.programs.claude-code`
declaration installs them for each home that requests Claude Code.

The `jake.neau` user declaration requests Claude Code on cedar. The other
machines run Pi. See [coding agents](coding-agents.md) for the per-user routing.

This subsystem is self-contained. Every skill Claude Code loads lives under
`modules/programs/claude-code/config/skills/`, including its writing, comment,
and documentation policies. `writing-lint.nix` builds its prose linter from
`modules/programs/claude-code/writing/`. This subsystem reads nothing from
another agent's tree, and no other agent's configuration reads from this one.
Each agent keeps its own copy of any policy that more than one agent wants, so
neither depends on the other's layout. See [Claude Code's writing
system](claude-code-writing-system.md) for the reasoning behind the writing
policies.

The config directory remains at `~/.claude`. The module leaves `configDir`
unchanged so that live state and project history continue to work.

## Inline content, not symlinked directories

The module deliberately avoids home-manager's `agentsDir`/`commandsDir`
options, which symlink whole source directories into `~/.claude`. Instead
each file is read into a string and handed to the module's *content*
options, so home-manager materialises real files. The trade-off is
visible in skills: only each skill's `SKILL.md` is inlined, so a skill
needing supporting files would have to switch to the directory form.

## Owning files vs merging policy

The subsystem splits `~/.claude` by who writes it:

- **Claude rewrites `settings.json` at runtime** (theme, effort level), so
  a declarative read-only symlink would freeze those knobs. Policy keys —
  the sandbox settings, enabled plugins, status line, hook registrations —
  are instead deep-merged into the live file at home activation with `jq`
  (`'. * $policy'`, our keys win). The known sharp edge: the merge is
  additive — a key removed from the Nix side survives in the live file
  until deleted by hand — and jq's `*` replaces arrays wholesale, so each
  hook event must list its complete set.
- **`keybindings.json` is read-only to Claude Code**, so it *is* a plain
  declarative file, like the status-line script.

## Sandbox and hooks as policy

The sandbox policy auto-allows sandboxed bash — read-only commands plus
network to the allowlisted domains in `_sandbox-allowed-domains.nix` —
while writes and unlisted hosts still prompt. Hook registrations wire the
development-flow hooks to tool events; the hook *scripts* are versioned in
`config/hooks/` and materialised executable.

Those hooks are deliberately **advisory**: every one of them injects context
and none blocks a tool call. `code-flow-reminder` restates the stage order
once a plan is approved, `code-flow-checklist` names any stage that never
ran, and `edit-briefing` annotates an edit's accept/deny prompt. An earlier
design enforced the same flow with hooks that blocked on exit 2, which made
a legitimately scaled-down flow impossible to complete; the order now lives
in the `code-writing-flow` skill and is followed by judgment.

## LSP servers pinned to the store

Every language nvf configures an LSP for gets the same server registered
for Claude Code, with commands pinned to absolute store paths so the
`claude` process resolves them regardless of PATH. The MCP side follows
the same declarative route: `programs.mcp.servers` plus
`enableMcpIntegration`, so a server added anywhere flows in automatically.
