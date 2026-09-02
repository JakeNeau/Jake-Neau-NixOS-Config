# GRUB theming

The Linux desktop role imports the `grub` program aspect from
`modules/programs/grub`. The aspect enables GRUB for UEFI systems and applies
Vinceliuice's Tela theme on both NixOS hosts. Darwin hosts do not import the
aspect.

## Firmware-safe output mode

GRUB uses the firmware's Graphics Output Protocol mode list. That list can omit
the native desktop resolution. Requesting an omitted mode makes GRUB probe the
mode and fall back, which can retrain the display and produce visible flicker.

The GRUB aspect therefore lets the firmware select the EFI mode with `auto`.
The Tela theme uses its 1080p assets and scales within the selected mode. The
host's `hostConstants.displayResolution` remains a desktop fact and does not
control the bootloader.

## Kernel handoff

The AMD graphics aspect loads `amdgpu` in the initial ramdisk. Without early
kernel modesetting, the initial ramdisk uses `simpledrm`. Stage 2 then replaces
that framebuffer with `amdgpu`, which causes another visible mode transition
long after GRUB exits.

Early loading moves that transition to the start of the initial ramdisk and
keeps the AMD framebuffer through the rest of boot. A transition can remain
when the firmware mode differs from the display's native mode.

## Custom-entry icons

GRUB resolves a menu icon from each entry's `--class` value. A custom entry must
name a class that has a corresponding PNG in the Tela theme. Redwood uses the
`windows` class for Windows and the `efi` class for firmware settings.

## Theme ownership

The GRUB aspect owns the bootloader enablement, UEFI settings, theme variant,
icons, footer, and resolution. Host aspects retain only machine-specific GRUB
settings, such as Redwood's generation limit and custom menu entries.

Stylix continues to theme the rest of each Linux system. Its GRUB target stays
disabled because only one module can own `boot.loader.grub.theme`.
