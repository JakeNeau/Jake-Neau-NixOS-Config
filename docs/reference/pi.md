# The pi module

`modules/programs/pi/pi.nix`: the `flake.programs.pi` declaration installing
the `pi` coding agent per-user — **bare, just the binary** — plus its flake
input and the numtide binary-cache aspect. It carries no declarative config
today; pi's config dir (`~/.pi/agent`) is left for the user to layer
home-manager config onto later. Why pi, and why it routes per user:
[coding agents](../explanation/coding-agents.md).

## The declaration

- `install.linux = ["home"]`, `install.macos = ["home"]` — per-user on both
  platforms. Delivered today by `flake.users.jakeneau.programs`
  ([add a per-user program](../how-to/declarations/add-a-per-user-program.md)).
- `hasEnableOption = false` + `packages` — no home-manager `programs.pi`
  module exists, so the generator supplies the enable toggle and installs the
  package behind it.
- The package is `inputs.llm-agents.packages.<system>.pi`, from
  **llm-agents.nix** (`github:numtide/llm-agents.nix`), declared via
  `flake-file.inputs` in the same file. The input deliberately has no
  `nixpkgs.follows`: cache.numtide.com only holds builds against the flake's
  own pin, and following our nixpkgs would rebuild pi and miss the cache.

The declaration has **no `config` block** — no `home.file` entries, no
activation script, no config policy. The install is nothing but the binary.

## The numtide cache aspect

`flake.modules.generic.numtide-cache`, in the same file:

- `nix.settings.extra-substituters = ["https://cache.numtide.com"]` and the
  matching `extra-trusted-public-keys` entry — the `extra-` prefix appends to
  the defaults instead of replacing them.
- System-scoped: all four hosts import it in their quirks aspects, never
  homes. It reaches the nix daemon only at a machine's next system rebuild;
  a pi home built before that compiles pi's Rust core from source.

## Config and state outside Nix

Nothing under `~/.pi/agent` is managed declaratively yet:

- **Config** — skills, subagents, MCP servers, `AGENTS.md`/`RULES.md`,
  extensions, and pi's own settings file are all absent from the module. The
  directory is open for the user to add config back incrementally.
- **Auth** — `/login` in pi (Anthropic subscription OAuth); tokens land under
  `~/.pi/agent`, never in Nix.

Ordering note: a machine's first pi home build should follow a system rebuild,
so the numtide cache (above) is active.
