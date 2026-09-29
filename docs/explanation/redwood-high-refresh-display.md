# Redwood high-refresh display policy

Redwood drives a Samsung Odyssey OLED G9 G95SC at 5120×1440 and 240 Hz over
DisplayPort 1.4. The monitor advertises this mode only when Game Mode is active.
The mode requires Display Stream Compression because its uncompressed signal
exceeds DisplayPort 1.4 bandwidth.

The RX 9070 XT display pipeline can trigger brief blackouts on some Samsung
panels during memory-clock changes. The driver changes its dynamic refresh
behavior during these transitions, and the panel can briefly lose the signal.
The upstream AMD report tracks this behavior in
[drm/amd#4753](https://gitlab.freedesktop.org/drm/amd/-/work_items/4753).

Niri therefore enables variable refresh rate continuously on `DP-1`. This
follows the upstream workaround, which prevents the problematic transitions
while retaining the native 240 Hz mode. Keep this setting until upstream
resolves the issue.

If blackouts or corruption continue, test the monitor at 120 Hz. Stable 120 Hz
operation isolates the failure to the high-bandwidth display path. Also verify
the monitor firmware and the DisplayPort cable before adding another driver
workaround.
