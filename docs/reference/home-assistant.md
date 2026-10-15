# Home Assistant control app

`modules/programs/home-assistant/home-assistant.nix` declares the Home Assistant control app. Redwood, Spruce, and Aspen request it through `globalPrograms`. Cedar does not request it.

## Platform routing

Linux uses the Home Manager install way. The generated `programs.home-assistant.enable` option installs a launcher and desktop entry. The launcher opens `https://ha.jakeneau.com` with Nixpkgs Ungoogled Chromium in standalone app mode. It uses the official Home Assistant icon.

macOS uses the `home-assistant` Homebrew cask. This cask installs the official Home Assistant Companion app. The host declaration owns the cask because Homebrew installs are machine-wide.

The declaration does not install the Nixpkgs `home-assistant` server or `go-hass-agent`.

## Pi MCP integration

The declaration adds `programs.home-assistant.enableMcpIntegration`. The option defaults to `true` whenever a home receives the Home Assistant program configuration.

Pi manages `~/.pi/agent/mcp.json` only when this option equals `true`. Linux also requires `programs.home-assistant.enable`. A missing Home Assistant option disables the integration, which keeps homes without the program valid.

The managed file registers `home-assistant` at `https://ha.jakeneau.com/api/mcp`. It uses OAuth Client ID Metadata Document registration through `cimd`.

Home Manager does not manage application login state or `~/.pi/agent/mcp-auth.json`. Each machine therefore keeps its Home Assistant and Pi OAuth credentials outside the Nix store. Disabling the MCP option removes the managed server declaration without deleting those credentials.

## Filesystem MCP companion

`modules/programs/home-assistant-filesystem/home-assistant-filesystem.nix` declares the Linux-only `home-assistant-filesystem` companion program. Redwood requests it through `globalPrograms` and imports its hand-written NixOS aspect. The Home Manager configuration requires the base Home Assistant program.

The NixOS aspect mounts Home Assistant's Samba `config` share at `/run/home-assistant-config`. This mount is root-only and reads its credentials from the sops-nix path for `homeAssistantSambaCredentials`. A `bindfs` mount exposes only `/config/www` at `/mnt/home-assistant-www` for `jakeneau`.

When a home enables the companion program, Pi adds the `home-assistant-filesystem` stdio server to `~/.pi/agent/mcp.json`. The server uses Nixpkgs `mcp-server-filesystem` and permits access only to `/mnt/home-assistant-www`.

## Dashboard lighting presets

The Apartment dashboard contains five lighting presets backed by scripts and exact-state template binary sensors.

- **Off** turns off every entity labeled `Preset Lights`.
- **Minimal** enables the living-room Tree and Vine lights, bedroom Paper Lights, and Kitchen Lamp.
- **Cozy** enables every `Preset Lights` entity except the living-room Vertical Lamp.
- **Bright** enables every `Preset Lights` entity except entities labeled `Work Lights`.
- **All** enables every `Preset Lights` entity, including `Work Lights`.

The dashboard uses local `custom:button-card` version 7.0.1 from `/config/www/community/button-card/button-card.js`. Each card observes its matching template binary sensor and highlights the complete card only when the managed lights exactly match that preset. Bright and All both highlight while no entity has the `Work Lights` label. An unmatched light combination highlights no preset. Each preset script calls light actions only for entities whose state must change.

Apply `Preset Lights` only to physical lights. Do not apply it to aggregate light groups. Apply both `Preset Lights` and `Work Lights` to future work lights.
