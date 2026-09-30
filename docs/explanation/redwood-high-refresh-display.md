# Redwood high-refresh display policy

Redwood drives a Samsung Odyssey OLED G9 G95SC at 5120×1440 and 240 Hz over
DisplayPort 1.4. The monitor advertises this mode only when Game Mode is active.
The mode requires Display Stream Compression because its uncompressed signal
exceeds DisplayPort 1.4 bandwidth.

Niri matches the monitor by its manufacturer, model, and serial number. This
identity keeps the 240 Hz mode and variable refresh rate active when the cable
moves between GPU ports.

Intermittent corruption and blackouts at 240 Hz produced DisplayPort symbol
errors. The errors occurred through two GPU ports, disappeared at 120 Hz, and
stopped after replacing the cable. Redwood therefore uses normal AMD power
management without a display-driver workaround.

If the failure returns, inspect the DisplayPort symbol-error counters before
changing the graphics configuration. Test another short, certified cable first.
Then investigate the monitor firmware or DisplayPort receiver. The native 120
Hz mode remains the diagnostic fallback.
