# Redwood high-refresh display policy

Redwood drives a Samsung Odyssey OLED G9 G95SC at 5120×1440 and 240 Hz over
DisplayPort 1.4. The monitor advertises this mode only when Game Mode is active.
The mode requires Display Stream Compression because its uncompressed signal
exceeds DisplayPort 1.4 bandwidth.

The RX 9070 XT display pipeline can trigger brief blackouts on some Samsung
panels during memory-clock changes. The driver changes its dynamic refresh
behavior during these transitions, and the panel can briefly lose the signal.

Niri therefore enables variable refresh rate continuously on `DP-1`. Persistent
VRR prevents the display corruption that occurs during dynamic refresh
transitions while retaining the native 240 Hz mode.

Persistent VRR does not prevent every blackout. Redwood also sets
`amdgpu.dcdebugmask=0x20000`, which disables firmware-assisted memory-clock
switching. This setting keeps the VRAM clock at its maximum while the display is
active and prevents blackouts during clock changes. It increases idle GPU power
consumption.

The upstream AMD reports track the remaining driver defect in
[drm/amd#4753](https://gitlab.freedesktop.org/drm/amd/-/work_items/4753) and the
exact monitor configuration in
[drm/amd#4795](https://gitlab.freedesktop.org/drm/amd/-/work_items/4795). Remove
the kernel parameter after upstream fixes memory-clock switching and Redwood
passes a 240 Hz test with automatic clocking.
