# The pi module

`modules/programs/pi/pi.nix`: the `flake.programs.pi` declaration installing
and configuring the `pi` coding agent per user. It supplies two web
capabilities: structured research through **pi-web-access**, and real-browser
fallback through **pi-agent-browser-native** plus the `agent-browser` CLI. Why
pi, and why it routes per user: [coding agents](../explanation/coding-agents.md).

## The declaration

- `install.linux = ["home"]`, `install.macos = ["home"]` — per-user on both
  platforms. Delivered by `flake.users.jakeneau.programs`.
- `hasEnableOption = false` + `packages` — the generator supplies the enable
  toggle and installs both pi and `agent-browser` behind it.
- Pi comes from `inputs.llm-agents.packages.<system>.pi`, via
  **llm-agents.nix** (`github:numtide/llm-agents.nix`). The input deliberately
  does not follow this flake's nixpkgs, preserving numtide's binary-cache hit.
- `agent-browser` is the upstream release binary, selected and hash-pinned per
  supported Linux/macOS architecture. Linux binaries are patched for NixOS.

## Web extensions

The module pins both extension sources as non-flake inputs:

- `pi-web-access` `v0.13.0` — `web_search`, content extraction, PDFs, GitHub,
  video handling, and its librarian skill.
- `pi-agent-browser-native` `v0.2.71` — the native `agent_browser` tool for
  JavaScript rendering and interactive browser workflows. It targets the
  installed `agent-browser` `0.32.2` release.

pi-web-access's runtime dependencies are built with `buildNpmPackage`; the
committed `pi-web-access-package-lock.json` and `npmDepsHash` make that build
reproducible. Small generated `index.ts` files under
`~/.pi/agent/extensions/` import each extension from its immutable store path.
The bundled librarian skill is linked under `~/.pi/agent/skills/`.

## Managed policy

Home Manager owns two focused policy files:

- `~/.pi/web-search.json` selects Exa, disables the interactive curator with
  `workflow = "none"`, and forbids browser-cookie extraction. This makes
  unattended runs return raw evidence to the main agent.
- `~/.pi/config/pi-agent-browser-native/config.json` disables that extension's
  companion search tool. pi-web-access owns search; `agent_browser` remains the
  JavaScript-capable fallback.

API keys are not stored in Nix. pi-web-access reads `EXA_API_KEY`,
`BRAVE_API_KEY`, and its other supported provider variables from the process
environment. Add credentials through sops-nix when needed.

Pi's mutable `~/.pi/agent/settings.json`, authentication, model catalog, and
session state remain outside Nix. The module only owns the extension entry
points, librarian skill link, and the two policy files above.

## The numtide cache aspect

`flake.modules.generic.numtide-cache`, in the same file, appends
`https://cache.numtide.com` and its trusted key to the daemon settings. Hosts
import it at system scope; homes never do. It reaches the daemon on the next
system rebuild.
