# Graphics self-activation

Vendor GPU modules activate themselves from one declared host fact. This keeps
GPU selection in one place.

## The pattern

The umbrella aspect, `graphics.nix`, imports every vendor module. It imports
`graphics-amd`, `graphics-intel`, and `graphics-nvidia` on NixOS. It imports
`graphics-apple` on Darwin. The aspect also enables vendor-neutral graphics
support and 32-bit support.

Each vendor module gates its body on `hostConstants.graphicsType`:

```nix
lib.mkIf (config.hostConstants.graphicsType == "nvidia") { ... }
```

A host declares its GPU with the required `hostConstants.graphicsType` fact.
Exactly one vendor module then activates. The NVIDIA module also activates its
hybrid graphics settings when `isLaptop` is true.

## Why self-activation

Import-based routing would make each host import its vendor module. That design
would state the same machine fact in the import and in each dependent feature.
Those declarations could then drift without an evaluation failure.

Self-activation makes the host state the fact once. Every consumer reads that
fact, including the vendor modules and GPU-aware programs. Adding another
GPU-aware behavior does not require a host change. This applies the Constants
pattern inside module evaluation, where modules can read host facts. See [host
facts](host-facts.md).

Every host evaluates every vendor module, but unmatched `mkIf` expressions
contribute nothing. The `graphics-apple` no-op completes the supported value
set. A host can therefore declare `graphicsType = "apple"` while macOS manages
the GPU itself.

## Early AMD modesetting

The AMD graphics aspect loads `amdgpu` in the initial ramdisk. Without early
kernel modesetting, the initial ramdisk uses `simpledrm`. Stage 2 then replaces
that framebuffer with `amdgpu`, which causes another visible mode transition.

Early loading moves that transition to the start of the initial ramdisk. It
keeps the AMD framebuffer through the rest of boot. A transition can remain
when the firmware mode differs from the display's native mode.
