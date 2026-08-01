# Redwood suspend policy

Redwood uses S3 deep sleep because its firmware configures the AMD GPUs for
that state. The integrated GPU rejects suspend-to-idle, and the discrete GPU
can fail to resume after that rejection. The resulting DRM failure can leave
Niri unusable and require a hard reset.

Systemd normally tries `mem`, `standby`, and `freeze` in that order. Selecting
`MemorySleepMode=deep` controls the mode used by `mem`, but it does not remove
the later states. If a pending wake event makes `mem` return an error, systemd
can try `freeze`, which enters suspend-to-idle.

Redwood sets both `MemorySleepMode=deep` and `SuspendState=mem`. This combination
selects S3 and removes the unsafe fallback. A pending wake event can still
cancel a suspend attempt, but systemd then returns the failure without entering
suspend-to-idle.
