# Steam font compatibility

Steam combines its bundled Fontconfig library with font data supplied by the
host. These components can have different versions. A large host font catalog
makes this boundary unstable and can leave the client without rendered text.

## Why Steam receives a bounded font set

The NixOS Steam module uses every package in `fonts.packages` by default. The
Steam FHS environment then exposes those packages under `/usr/share/fonts`.
NixOS Fontconfig also exposes the same packages through its generated cache.
Steam can therefore discover each font through several paths.

The unfiltered `google-fonts` package contains the complete Google Fonts
catalog. It is not suitable as a general desktop fallback because it adds
thousands of unrelated faces to Steam's search space. The desktop role omits
that catalog and relies on the NixOS default packages for broad Unicode, CJK,
and emoji coverage. It adds `noto-fonts` for the remaining Noto families.

Redwood sets `programs.steam.fontPackages` explicitly. The set includes Latin,
CJK, emoji, and the configured Montserrat interface font. This option bounds
the packages mounted under Steam's `/usr/share/fonts`. Host Fontconfig can
still expose declared system fonts, so the desktop catalog must also stay
bounded.

The desktop role also leaves `fonts.fontDir.enable` disabled. That option
creates a legacy X11 core-font directory. Modern Steam rendering uses
Fontconfig and does not need the additional path.

If an older cache still contains the previous paths, follow
[Repair Steam font rendering](../how-to/repair-steam-fonts.md).
