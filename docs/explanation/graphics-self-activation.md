# Graphics self-activation

Why the per-vendor GPU modules under `modules/host-config/graphics/`
activate themselves, and what the pattern buys.

## The pattern

The umbrella aspect (`graphics.nix`) imports *every* vendor module —
`graphics-amd`, `graphics-intel`, `graphics-nvidia` on NixOS,
`graphics-apple` on darwin — unconditionally, plus the vendor-neutral
enablement (`hardware.graphics.enable`, 32-bit support). Each vendor
module then gates its own body:

```nix
lib.mkIf (config.hostConstants.graphicsType == "nvidia") { ... }
```

A host declares only the GPU it has — `hostConstants.graphicsType`, a
required fact with no default — and exactly one vendor module comes alive.
The nvidia module layers a second self-activating slice for laptop hybrid
graphics, gated on `graphicsType == "nvidia" && isLaptop`.

## Why self-activation

The alternative is routing by import: each host imports its vendor's
module. That scatters the same machine fact across two places — the import
line and any feature that branches on the vendor — and drift between them
is silent. Self-activation inverts the dependency: the fact is stated once
on the host, and every consumer (the vendor modules, but also programs
like blender's ROCm switch and davinci-resolve's OpenCL setup) branches on
the same `hostConstants.graphicsType`. Adding a vendor-aware behavior
never touches a host file. This is the Constants pattern doing routing
*inside* module eval — the layer where facts are readable (see [host
facts](host-facts.md)).

The cost is that every host evaluates every vendor module. That is cheap:
an unmatched `mkIf` contributes nothing, and `graphics-apple` is an
explicit no-op that exists to complete the set — declaring
`graphicsType = "apple"` stays meaningful on machines whose OS drives the
GPU itself.
