# Monitor power control

The monitor-power feature coordinates compositor output state with monitor
firmware power. Niri can disable a video output, but some monitors treat the
missing signal as a reason to scan inputs instead of entering standby.

The `monitor-power` command accepts `on` or `off`. It coordinates Niri's output
action with the backends declared by the current home. Power-off runs the
firmware backends before disabling Niri outputs. Power-on enables Niri outputs
before running the firmware backends. The `monitor-power-transition` command
wraps sleep, reboot, and shutdown requests around those actions.

DDC/CI is the default backend for Niri desktops. A host selects additional
backend packages through its own configuration.

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

Redwood enables post-resume restoration for suspend and hibernate. Its
transition command powers the monitors off and requests system sleep without
trying to restore them immediately. The `systemctl` command can return before
the system sleeps, so commands after it cannot represent post-resume work.

The `monitor-power-resume-users` system service runs after the system sleep
target completes. It starts the `monitor-power-resume` service in Jake's user
manager. The user service runs `monitor-power on` with the Niri session
environment. Other hosts retain the direct transition behavior unless they
enable both resume services.

Before standby, the Samsung backend resolves the monitor hostname and caches
its network address in the user's cache directory. Power-on uses that address
because a standby monitor may stop advertising its mDNS hostname. The backend
also retries the monitor state API for up to 30 seconds while host networking
recovers after resume.

Reboot and shutdown rely on the Niri startup command in the next session.
Network access and the monitor's remote-control setting must be available at
those points. Backend failures produce a warning but do not block the system
transition.

The Odyssey can miss its DisplayPort reconnect event after someone uses its
physical power button. Niri then records the `DP-1` disconnection but receives
no event when the monitor returns. Redwood force-reprobes that connector every
five seconds while DRM reports it disconnected. A successful probe updates the
DRM state and emits the event that lets Niri restore the output. Switching to
another TTY and back also forces Niri to recheck the connector.

On Redwood, `Mod+Semicolon` signals swayidle to enter its idle state. Swayidle
runs `monitor-power off`, then runs `monitor-power on` after the next mouse or
keyboard input. A short delay prevents the shortcut's key release from
immediately waking the monitor. The configured timeout is effectively
unreachable, so inactivity alone does not turn off the monitors. Other hosts
retain Niri's DPMS-only behavior.
