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

Writing, comment, and documentation policies live under
`modules/programs/agents-shared/skills/` because both agents use them. Claude
merges those policies with its own skills. Pi indexes only the shared policies
and its own skills.

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
development-flow gates (plan-verifier, code-writer, code-review gates) to
tool events; the hook *scripts* are versioned in `config/hooks/` and
materialised executable.

## LSP servers pinned to the store

Every language nvf configures an LSP for gets the same server registered
for Claude Code, with commands pinned to absolute store paths so the
`claude` process resolves them regardless of PATH. The MCP side follows
the same declarative route: `programs.mcp.servers` plus
`enableMcpIntegration`, so a server added anywhere flows in automatically.
