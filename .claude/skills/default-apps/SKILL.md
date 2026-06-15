---
name: default-apps
description: How to set a program as the default handler for a file type or URL scheme across NixOS and macOS in this repo. Linux uses home-manager's xdg.mimeApps; macOS has no declarative LaunchServices option, so a home.activation script drives `duti` — and MUST guard on the current handler, because macOS pops an anti-hijacking confirmation modal on every programmatic change to a protected type (pdf, http, https, mailto, html). Use when making an app the default for an extension/MIME type/scheme, or when a rebuild keeps popping a "Do you want all documents … to open with …?" modal.
---

# Setting default programs (NixOS + macOS)

Registering an app as the default handler for a file type or URL scheme is
**per-OS**, so it belongs in a cross-platform home-manager aspect split with
`lib.mkMerge` + `pkgs.stdenv.isLinux` / `isDarwin` (see the `nix-config` skill
for the aspect rules). The two canonical examples in this repo are
`modules/programs/sioyek/sioyek.nix` (PDF) and
`modules/programs/librewolf/librewolf.nix` (browser) — copy their shape.

## Linux — `xdg.mimeApps` (declarative, no gotchas)

Linux has a real declarative option. Set the MIME type to the app's `.desktop`
file:

```nix
(lib.mkIf pkgs.stdenv.isLinux {
  xdg.mimeApps = {
    enable = true;
    defaultApplications."application/pdf" = "sioyek.desktop";
    # browsers also take the scheme handlers:
    # "x-scheme-handler/https" = "librewolf.desktop";
  };
})
```

That's it — it's idempotent and writes `~/.config/mimeapps.list`.

## macOS — guarded `duti` activation (the part with the trap)

macOS LaunchServices has **no declarative nix-darwin/home-manager option**, so we
set the handler imperatively from a `home.activation` script using `duti`
(`home.packages = [pkgs.duti];`).

**The trap:** `pdf`, `http`, `https`, `mailto`, and `html` are *protected*
content types. Any programmatic `duti -s` on them makes macOS pop an
anti-hijacking confirmation modal:

> Do you want all documents with the extension ".pdf" to open with "…", or to
> keep using "Preview"?

A naive activation runs `duti -s` on **every** rebuild, so the modal reappears
every rebuild (and if the user clicks "keep using …", it never even sticks).

**The fix: guard on the current handler and only call `duti -s` when it differs.**
`duti -d <type>` prints the current default's bundle id and works for both UTIs
**and** URL schemes. With the guard, the modal appears at most once (the first
switch); afterwards every rebuild sees the handler already set and skips the call.

Single type (PDF):

```nix
(lib.mkIf pkgs.stdenv.isDarwin {
  home.packages = [pkgs.duti];
  home.activation.sioyekDefaultPdf =
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ "$(${lib.getExe pkgs.duti} -d com.adobe.pdf 2>/dev/null)" != "info.sioyek.sioyek" ]; then
        $DRY_RUN_CMD ${lib.getExe pkgs.duti} -s info.sioyek.sioyek com.adobe.pdf all || true
      fi
    '';
})
```

Several types for one app (browser) — loop so the guard applies to each:

```nix
(lib.mkIf pkgs.stdenv.isDarwin {
  home.packages = [pkgs.duti];
  home.activation.librewolfDefaultBrowser =
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      for type in http https public.html; do
        if [ "$(${lib.getExe pkgs.duti} -d "$type" 2>/dev/null)" != "org.mozilla.librewolf" ]; then
          $DRY_RUN_CMD ${lib.getExe pkgs.duti} -s org.mozilla.librewolf "$type" all || true
        fi
      done
    '';
})
```

Notes:
- Keep `$DRY_RUN_CMD` (respects home-manager dry-runs) and the trailing
  `|| true` (a failed/declined `duti` must not abort activation).
- The third `duti` arg is the **role**; `all` covers viewer + editor.
- The guard compares against the desired bundle id. Once the user accepts the
  modal once, the choice persists in LaunchServices and the guard short-circuits.

## Finding the identifiers you need

Run these on a macOS machine (read-only):

```sh
duti -d com.adobe.pdf          # current default bundle id for a UTI
duti -d https                  # current default bundle id for a URL scheme
duti -x pdf                    # handler app name, path, and bundle id for an extension
osascript -e 'id of app "Sioyek"'                 # an installed app's bundle id
mdls -name kMDItemContentType somefile.pdf         # the UTI of a real file
```

Common values: PDF UTI `com.adobe.pdf`; HTML UTI `public.html`; URL schemes are
the bare scheme (`http`, `https`, `mailto`). Bundle ids seen here:
`info.sioyek.sioyek`, `org.mozilla.librewolf`, `com.apple.Preview`.

## Validating

This is an activation script, not build-time config, so a dry build only checks
that the nix evaluates — it won't exercise the `duti` logic. Per `AGENTS.md` /
the `nix-config` skill, **don't** run `switch`/`nr`; the user runs the rebuild
and confirms the modal stops reappearing.

## DRY note

The macOS block is near-identical across apps (only the bundle id + type list
change). If a third app needs a default handler, consider factoring a small
helper (e.g. a function taking bundle id + list of types that emits the guarded
activation) rather than copy-pasting a third time.
