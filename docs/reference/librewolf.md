# LibreWolf

LibreWolf is the personal user's default browser. Home Manager declares four
profiles with separate state and command and graphical launchers.

## Profiles

| Profile | Purpose | Extensions | Privacy mode | Stylix |
|---|---|---|---|---|
| `work` | Default profile for general productivity | Six productivity extensions | Clear cookies and site storage except for manually allowed sites | Yes |
| `strict` | Personal browsing and the existing browser state | All declared extensions | Clear cookies and site storage on shutdown, with no exceptions | Yes |
| `compatibility` | Sites that reject stronger privacy behavior | Bitwarden and Chrome Mask | Clear cookies and site storage except for the same manually allowed sites as work | Yes |
| `development` | Extension-free page testing | None | Clear cookies and site storage on shutdown, with no exceptions | No |

All profiles retain LibreWolf's security controls. Every profile uses the
shared search configuration. Only `strict` and `work` use the declared
bookmarks and uBlock settings.

## Persistence exceptions

All profiles clear cookies and site storage during normal shutdown. The user
keeps the same manual persistence exceptions in `work` and `compatibility`.
The `strict` and `development` profiles have no exceptions.

The profiles do not share browser state. An allowed site stores separate
cookies and site data in `work` and `compatibility`. Home Manager does not
modify the browser-owned `permissions.sqlite` databases. Shutdown clearing may
not complete after a browser crash or forced process termination.

## Launchers

| Profile | Command | Graphical name | Icon |
|---|---|---|---|
| `work` | `librewolf-work` | LibreWolf | Standard LibreWolf icon |
| `strict` | `librewolf-strict` | LibreWolf Strict | Red `S` badge |
| `compatibility` | `librewolf-compatibility` | LibreWolf Compatibility | Amber `C` badge |
| `development` | `librewolf-development` | LibreWolf Development | Violet `D` badge |

Each launcher opens its named profile. It reuses that profile's running
instance when one exists, which avoids profile-lock failures. Badges appear at
the lower-right corner and use Rubik Bold. Variants below 48 pixels
use solid colors and larger relative dimensions. Larger variants use a subtle
gradient.

Linux uses desktop entries for all four profiles.

Linux renders every icon size from the configured GTK icon theme. It installs
named variants under `hicolor`.

macOS uses the native LibreWolf app for work. Home Manager generates app
bundles for the other profiles. Each generated app uses the native icon's
standard and Retina ICNS representations. The profile badge does not change the
icon's displayed size. Only LibreWolf remains the registered default browser.

## Migration constraint

The `strict` profile must keep path `default`. That path preserves the browser
data that predates the four-profile configuration. Its first normal shutdown
under the new settings clears cookies and site storage. The default `work`
profile has ID 0, and `strict` has ID 1.
