---
name: configuring-mcp-servers
description: How to add a Model Context Protocol (MCP) server for Claude Code in this repo — declared declaratively via programs.mcp.servers (Nix), which flows into Claude through enableMcpIntegration (NOT a file under config/). Covers stdio vs http/sse transports, the command/args/env/url/headers schema, keeping secrets out of plaintext, and the trust model. Use when connecting Claude to an external tool or data source via MCP.
---

# Configuring MCP servers

MCP connects Claude to external tools and data sources. Like LSP, this is **not**
a file under `config/` — it is a **Nix attrset**.

## Where it goes — edit Nix, not a file

`enableMcpIntegration = true` is already set in
`modules/programs/claude-code/claude-code.nix`, so any server declared in
**`programs.mcp.servers`** flows automatically into Claude's `~/.claude/.mcp.json`
on rebuild. There is **no `programs.mcp` module in this repo yet**, so the first
server also means enabling that home-manager module. Workflow otherwise: edit →
`git add` → rebuild (see [[claude-code-config]]).

## Schema (home-manager `programs.mcp.servers.<name>`)

```nix
programs.mcp.servers.context7 = {
  # remote (http/sse):
  url = "https://mcp.context7.com/mcp";
  headers = {Authorization = "Bearer …";};
  # OR local (stdio):
  # command = "npx";
  # args = ["-y" "@some/mcp-server"];
  # env = { API_KEY = { file = "/run/secrets/api_key"; }; };
};
```

- **stdio** (local process): `command` + `args` + `env`.
- **remote**: `url` + `headers`.
- `env` values may be `{ file = ...; }` to read a secret from a file.
- `enabled` toggles a server without deleting it.

## Best practices

- **Least privilege:** enable only servers you need — each one spends context on
  its tool schemas at session start.
- **Never put secrets in plaintext `.nix`.** Use sops-nix and reference the
  decrypted file via `env.<VAR>.file` (see secrets in [[machine-layout]] and
  [[configuring-sops-secrets]]).
- **Vet third-party servers** before adding them; they run with your access.
- Give servers clear, stable names.

## Reference

Official docs (transports, scopes, auth, trust model):
https://code.claude.com/docs/en/mcp

## Related skills

- [[claude-code-config]] — the declarative edit/ship workflow
- [[machine-layout]] — secrets (sops-nix) and where the Nix modules live
- [[configuring-sops-secrets]] — handling MCP credentials (future skill)
