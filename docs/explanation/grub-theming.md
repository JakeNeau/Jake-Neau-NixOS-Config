# GRUB theming

The Spruce host imports the `grub` program aspect from
`modules/programs/grub`. The aspect enables GRUB for UEFI systems and applies
Vinceliuice's Tela theme. Redwood uses Lanzaboote instead, and Darwin hosts do
not import either NixOS bootloader aspect.

## Firmware-safe output mode

GRUB uses the firmware's Graphics Output Protocol mode list. That list can omit
the native desktop resolution. Requesting an omitted mode makes GRUB probe the
mode and fall back, which can retrain the display and produce visible flicker.

The GRUB aspect therefore lets the firmware select the EFI mode with `auto`.
The Tela theme uses its 1080p assets and scales within the selected mode. The
host's `hostConstants.displayResolution` remains a desktop fact and does not
control the bootloader.

## Theme ownership

The GRUB aspect owns Spruce's bootloader enablement, UEFI settings, theme
variant, icons, footer, and resolution.

Stylix continues to theme the rest of each Linux system. Its GRUB target stays
disabled because only one module can own `boot.loader.grub.theme`.
