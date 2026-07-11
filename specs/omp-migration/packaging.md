# oh-my-pi packaging and routing

Sub-spec of [`omp-migration.md`](omp-migration.md): the flake input that supplies
the `omp` package, the two program declarations, and the per-user routing that
performs the swap.

## Spec

- The `omp` package comes from **llm-agents.nix**
  (`github:numtide/llm-agents.nix`), which packages omp with daily automated
  upstream bumps and a binary cache at `cache.numtide.com` — so the ~55k-line
  Rust core is never built locally and the pin still moves only when
  `flake.lock` does.
- omp becomes a `flake.programs.oh-my-pi` declaration installing per-user
  ("home") on both platforms.
- The existing hand-written `flake.modules.homeManager.claude-code` aspect is
  **converted** into a `flake.programs.claude-code` declaration carrying the same
  config module, content unchanged — so both agents ride the same declaration
  channel and per-user routing works uniformly.
- Routing is pure per-user: `jakeneau` → oh-my-pi, `jake.neau` → claude-code.
  The `claude-code` entry leaves the `role-desktop` homeManager aggregate.

## Plan

### Flake input (`modules/programs/oh-my-pi/oh-my-pi.nix`)

Add the input via `flake-file.inputs` in the new module — never hand-edit
`flake.nix` — then regenerate with `nix run .#write-flake`:

```nix
flake-file.inputs.llm-agents.url = "github:numtide/llm-agents.nix";
```

(Pattern precedent: `modules/nix/tools/mac-app-util/mac-app-util.nix`. Do **not**
add `inputs.nixpkgs.follows = "nixpkgs"` without checking the README's caveat:
following our nixpkgs changes the build inputs and defeats the binary cache —
mac-app-util has the same deliberately-omitted-follows precedent.)

### Binary cache

Wire the numtide cache into `nix.settings` (substituter + trusted public key) via
a small hand-written aspect in the oh-my-pi folder (a `generic`-class module
imported by the hosts' quirks aspects, per the typed-imports rule), since the
declaration framework routes no system-level config for a "home" install.

Be honest about when this helps: the aspect lands as `nix.settings`, which only
reaches the nix daemon after a system rebuild (`nr`) — and no `nr` runs during
implementation. Cedar's daemon today trusts only cache.nixos.org, and `jake.neau`
is not in `trusted-users`, so user-passed substituters are ignored there; nothing
this aspect does can make implementation-time builds on cedar hit the numtide
cache. Its purpose is each machine's *next* `nr`: after that rebuild, every omp
home build pulls the Rust core from cache instead of compiling it. Import it on
**all four hosts** so every machine that ever builds an omp home benefits; on
cedar the extra substituter is harmless and changes no closure. (Implementation
consequence: validation below never full-builds an omp home — see Validation —
and the overview's per-machine user actions note that `nr` must precede the
user's `hr`.)

llm-agents.nix ships no ready-made cache module, so the aspect hand-writes the
two lines itself:

```nix
nix.settings.extra-substituters = ["https://cache.numtide.com"];
nix.settings.extra-trusted-public-keys = ["niks3.numtide.com-1:<key>"];
```

Note the `extra-` prefixes deliberately: `extra-substituters` *appends* to the
substituter list rather than replacing it, unlike bare `substituters`. The
implementer copies the exact public-key string from the llm-agents.nix README.

### `flake.programs.oh-my-pi` declaration

In `modules/programs/oh-my-pi/`:

```nix
flake.programs.oh-my-pi = {
  install.linux = ["home"];
  install.macos = ["home"];   # install ways are lists in the schema
  hasEnableOption = false;    # no HM programs.oh-my-pi module exists
  packages = pkgs: [inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp];
  config = <the omp config module — see omp-config.md>;
};
```

(`hasEnableOption = false` + `packages` is the `kubernetes` declaration's
precedent: the generator supplies the enable toggle and installs the packages
behind it.)

Package sourcing is the direct input-packages reference shown above — no
overlay. The repo has no in-repo precedent for either mechanism, and both hit
the binary cache equally, so the direct reference wins on simplicity. (The
attribute name is verified: llm-agents.nix packages it as **`omp`**, built from
source with Rust + bun, cached at cache.numtide.com.)

### Convert claude-code to a declaration

In `modules/programs/claude-code/claude-code.nix`:

- Replace the hand-written `flake.modules.homeManager.claude-code = <module>`
  with:

  ```nix
  flake.programs.claude-code = {
    install.linux = ["home"];
    install.macos = ["home"];
    config = <module>;   # the current module body, verbatim
  };
  ```

- The module body moves into `config` **unchanged** (helpers, settingsPolicy,
  hooks, lspServers, mcp wiring, activation merge, keybindings, statusline).
  home-manager has a real `programs.claude-code` module, so `hasEnableOption`
  keeps its default `true`; the body's own `programs.claude-code.enable = true`
  merges harmlessly with the generated unit's.
- This must land in the **same commit** as the routing change below — not
  because the units collide (the conversion deletes the hand-written
  `flake.modules.homeManager.claude-code` as it creates the declaration, so
  they never coexist and a conversion-only commit would be valid), but because
  the routing edits only make sense together: removing the role-desktop entry
  without the `jake.neau` user entry silently strips claude-code from cedar,
  and adding the user entry without removing the role-desktop import
  double-delivers it.

### Routing

- `modules/host-config/roles/desktop/desktop.nix`: remove `claude-code` from the
  `flake.modules.homeManager.role-desktop` imports list (it sits between `nvf`
  and `cli-tools`).
- `modules/users/jakeneau/jakeneau.nix`: add
  `flake.users.jakeneau.programs = ["oh-my-pi"];` (this user's first `flake.users`
  declaration; it sits alongside the factory stamping).
- `modules/users/jake.neau/jake.neau.nix`: add
  `flake.users."jake.neau".programs = ["claude-code"];` alongside the existing
  `hosts.cedar.programs = ["kubernetes"]` entry.

Net effect: every home keeps exactly one agent, delivered through exactly one
channel — no double delivery, no host conditionals.

### Validation

`nix flake check`. Then, because the numtide cache is inactive until each
machine's next `nr` (see the cache section), never full-build an omp home during
implementation:

- all three jakeneau homes by activationPackage **drvPath eval** —
  `nix eval --raw '.#homeConfigurations."jakeneau@<host>".activationPackage.drvPath'`.
  The Linux two can only be evaluated anyway (no Linux builder on this Mac);
  aspen's is deliberately eval-only so omp's Rust core is never source-built
  before the cache is active.
- full `nix build --no-link` for cedar's home (`jake.neau@cedar`) and both
  darwin systems.
- redwood/spruce by toplevel drvPath eval, as before.

`git add` new files first.

## Tasks

1. **Input + cache.** Create `modules/programs/oh-my-pi/oh-my-pi.nix` with the
   `flake-file.inputs.llm-agents` entry and the cache aspect
   (`extra-substituters` / `extra-trusted-public-keys`, key copied from the
   llm-agents.nix README); import the cache aspect from all four hosts' quirks
   aspects; run `nix run .#write-flake`; `git add`; validate.
2. **oh-my-pi declaration.** Add `flake.programs.oh-my-pi` with the package
   sourced from the input and a minimal `config` stub (fleshed out by
   [`omp-config.md`](omp-config.md)); validate.
3. **claude-code conversion + routing.** In one commit: convert the claude-code
   aspect to `flake.programs.claude-code`, remove `claude-code` from
   role-desktop's homeManager imports, add both `flake.users` program entries;
   validate all homes and hosts.
