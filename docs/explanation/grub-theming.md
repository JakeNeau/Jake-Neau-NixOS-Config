# GRUB theming

The Linux desktop role imports the `grub` program aspect from
`modules/programs/grub`. The aspect enables GRUB for UEFI systems and applies
Vinceliuice's Tela theme on both NixOS hosts. Darwin hosts do not import the
aspect.

## Per-host output mode

Each host declares `hostConstants.displayResolution.horizontal` and
`hostConstants.displayResolution.vertical`. The GRUB aspect converts these
pixel counts into the theme module's `WIDTHxHEIGHT` custom resolution. The
upstream module sets the same mode for EFI and BIOS, with `auto` as a fallback.

A display resolution describes the primary display. It does not model a
machine's complete monitor inventory. Features that need every monitor should
use a separate structured fact.

## Theme ownership

The GRUB aspect owns the bootloader enablement, UEFI settings, theme variant,
icons, footer, and resolution. Host aspects retain only machine-specific GRUB
settings, such as Redwood's generation limit and custom menu entries.

Stylix continues to theme the rest of each Linux system. Its GRUB target stays
disabled because only one module can own `boot.loader.grub.theme`.
