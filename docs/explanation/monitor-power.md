# Monitor power control

The monitor-power feature coordinates compositor output state with monitor
firmware power. Niri can disable a video output, but some monitors treat the
missing signal as a reason to scan inputs instead of entering standby.

The `monitor-power` command accepts `on` or `off`. It coordinates Niri's output
action with the backends declared by the current home. Power-off runs the
firmware backends before disabling Niri outputs. Power-on enables Niri outputs
before running the firmware backends. DDC/CI is the default backend for Niri
desktops. A host selects additional backend packages through its own
configuration.

The generic `flake.lib.monitorPower.samsungTizen` function builds a Samsung
Tizen backend package. A host supplies the package name, monitor hostname,
token path, and remote name. The function packages the shared Samsung
implementation without embedding a pairing token in the Nix store.

## Redwood's Samsung backend

Redwood creates the `redwoodSamsungOdysseyG9` backend for its Odyssey OLED G9.
Its configuration supplies `samsung.local`, the Redwood-specific secret path,
and the `redwood-monitor-power` remote name. No Samsung device value resides in
the generic backend.

Redwood also keeps DDC/CI enabled. DDC/CI controls any temporary monitor that
supports it. The Odyssey accepts DDC power commands but continues showing its
no-signal interface. Its Samsung Tizen API enters firmware standby instead.

The backend checks the API's reported power state before sending `KEY_POWER`.
It sends the key only for these transitions:

- `on` to `standby` when powering off.
- `standby` to `on` when restoring power.

The state check matters because `KEY_POWER` is a toggle. Sending it without the
check could reverse an already completed transition.

The backend connects to `samsung.local` over the token-authenticated Tizen
WebSocket API. The pairing credential is the
`redwoodSamsungOdysseyG9Token` sops secret. Sops-nix decrypts the secret for
`jakeneau` at activation without placing it in the Nix store.

Suspend and hibernate restore the monitor after the system resumes. Reboot and
shutdown rely on the Niri startup command in the next session. Network access
and the monitor's remote-control setting must be available at those points.
Backend failures produce a warning but do not block the system transition.

The ordinary `Mod+Semicolon` binding remains Niri DPMS-only. Any input can then
restore the output without requiring the Samsung API.
