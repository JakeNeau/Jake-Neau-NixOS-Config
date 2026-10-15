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
