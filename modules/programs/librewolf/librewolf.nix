{
  flake.modules.homeManager.librewolf = {
    config,
    pkgs,
    lib,
    ...
  }: let
    commonProfileSettings = {
      "extensions.autoDisableScopes" = 0;
      "privacy.sanitize.sanitizeOnShutdown" = true;
      "privacy.clearOnShutdown.cookies" = true;
      "privacy.clearOnShutdown.offlineApps" = true;
      "privacy.clearOnShutdown_v2.cookiesAndStorage" = true;
      "privacy.trackingprotection.allow_list.baseline.enabled" = true;
      "privacy.trackingprotection.allow_list.convenience.enabled" = true;
    };

    strictSettings = lib.mkMerge [
      commonProfileSettings
      {"privacy.resistFingerprinting.reduceTimerPrecision.jitter" = false;}
    ];

    workSettings = lib.mkMerge [
      commonProfileSettings
      {
        "privacy.clearOnShutdown.cookies" = lib.mkForce false;
        "privacy.clearOnShutdown.offlineApps" = lib.mkForce false;
        "privacy.clearOnShutdown_v2.cookiesAndStorage" = lib.mkForce false;
        "privacy.resistFingerprinting" = false;
        "privacy.fingerprintingProtection" = true;
        "privacy.fingerprintingProtection.overrides" = "+AllTargets,-CSSPrefersColorScheme";
      }
    ];

    compatibilitySettings = lib.mkMerge [
      commonProfileSettings
      {
        "privacy.resistFingerprinting" = false;
        "privacy.fingerprintingProtection" = false;
        "librewolf.webgl.prompt" = false;
      }
    ];

    searchConfig = {
      force = true;
      default = "brave";
      privateDefault = "brave";
      order = [
        "brave"
        "nix-options"
        "nix-packages"
        "home-manager"
        "nixos-wiki"
        "wikipedia"
      ];
      engines = {
        brave = {
          name = "Brave";
          urls = [
            {
              template = "https://search.brave.com/search";
              params = [
                {
                  name = "source";
                  value = "web";
                }
                {
                  name = "q";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
          icon = "https://upload.wikimedia.org/wikipedia/commons/d/da/Brave_search_logo.png";
          definedAliases = ["@b"];
        };

        home-manager = {
          name = "Home Manager Options";
          urls = [
            {
              template = "https://home-manager-options.extranix.com";
              params = [
                {
                  name = "release";
                  value = "master";
                }
                {
                  name = "query";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
          iconMapObj."16" = "https://wiki.nixos.org/favicon.ico";
          definedAliases = ["@ho"];
        };

        nix-options = {
          name = "Nix Options";
          urls = [
            {
              template = "https://search.nixos.org/options";
              params = [
                {
                  name = "sort";
                  value = "relevance";
                }
                {
                  name = "channel";
                  value = "unstable";
                }
                {
                  name = "type";
                  value = "packages";
                }
                {
                  name = "query";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = ["@no"];
        };

        nix-packages = {
          name = "Nix Packages";
          urls = [
            {
              template = "https://search.nixos.org/packages";
              params = [
                {
                  name = "type";
                  value = "packages";
                }
                {
                  name = "channel";
                  value = "unstable";
                }
                {
                  name = "query";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = ["@np"];
        };

        nixos-wiki = {
          name = "NixOS Wiki";
          urls = [{template = "https://wiki.nixos.org/w/index.php?search={searchTerms}";}];
          iconMapObj."16" = "https://wiki.nixos.org/favicon.ico";
          definedAliases = ["@nw"];
        };

        wikipedia = {
          name = "Wikipedia";
          urls = [{template = "https://en.wikipedia.org/wiki/{searchTerms}";}];
          icon = "https://upload.wikimedia.org/wikipedia/en/8/80/Wikipedia-logo-v2.svg";
          definedAliases = ["@w"];
        };
      };
    };

    bookmarkConfig = {
      force = true;
      settings = [
        {
          name = "Home Manager Wiki";
          tags = ["wiki" "nix"];
          url = "https://wiki.nixos.org/";
        }
        {
          name = "Toolbar Bookmarks";
          toolbar = true;
          bookmarks = [
            {
              name = "Nixos Wiki";
              tags = ["Wiki" "Nix"];
              url = "https://wiki.nixos.org/";
            }
            {
              name = "Rust";
              tags = ["documentation"];
              url = "https://rust-book.cs.brown.edu/title-page.html";
            }
          ];
        }
      ];
    };

    firefoxAddons = pkgs.nur.repos.rycee.firefox-addons;

    strictExtensionPackages = with firefoxAddons; [
      bitwarden
      chrome-mask
      darkreader
      don-t-fuck-with-paste
      return-youtube-dislikes
      sponsorblock
      tridactyl
      ublock-origin
      youtube-shorts-block
    ];

    workExtensionPackages = with firefoxAddons; [
      bitwarden
      chrome-mask
      darkreader
      don-t-fuck-with-paste
      tridactyl
      ublock-origin
    ];

    compatibilityExtensionPackages = with firefoxAddons; [
      bitwarden
      chrome-mask
    ];

    mkExtensions = packages: {
      force = true;
      inherit packages;
    };

    ublockSettings = {
      settings."uBlock0@raymondhill.net" = {
        force = true;
        settings.selectedFilterLists = [
          "ublock-filters"
          "ublock-badware"
          "ublock-privacy"
          "ublock-unbreak"
          "ublock-quick-fixes"
          "easylist"
          "../patches/2_without_easylist/2_without_easylist-s-1755209474-3600.patch"
        ];
      };
    };

    strictExtensions = lib.mkMerge [
      (mkExtensions strictExtensionPackages)
      ublockSettings
    ];

    workExtensions = lib.mkMerge [
      (mkExtensions workExtensionPackages)
      ublockSettings
    ];

    compatibilityExtensions = mkExtensions compatibilityExtensionPackages;
    developmentExtensions = mkExtensions [];

    profiles = {
      work = {
        id = 0;
        name = "work";
        path = "work";
        isDefault = true;
        settings = workSettings;
        search = searchConfig;
        bookmarks = bookmarkConfig;
        extensions = workExtensions;
      };

      strict = {
        id = 1;
        name = "strict";
        path = "default";
        isDefault = false;
        settings = strictSettings;
        search = searchConfig;
        bookmarks = bookmarkConfig;
        extensions = strictExtensions;
      };

      compatibility = {
        id = 2;
        name = "compatibility";
        path = "compatibility";
        isDefault = false;
        settings = compatibilitySettings;
        search = searchConfig;
        extensions = compatibilityExtensions;
      };

      development = {
        id = 3;
        name = "development";
        path = "development";
        isDefault = false;
        settings = compatibilitySettings;
        search = searchConfig;
        extensions = developmentExtensions;
      };
    };

    profileNames = [
      "work"
      "strict"
      "compatibility"
      "development"
    ];

    browserExecutable =
      if pkgs.stdenv.isDarwin
      then "${config.programs.librewolf.finalPackage}/Applications/LibreWolf.app/Contents/MacOS/librewolf"
      else lib.getExe config.programs.librewolf.finalPackage;

    mkProfileLauncher = profile:
      pkgs.writeShellApplication {
        name = "librewolf-${profile}";
        text = ''
          exec ${browserExecutable} \
            -P ${lib.escapeShellArg profile} \
            "$@"
        '';
      };

    profileLaunchers = lib.genAttrs profileNames mkProfileLauncher;
    profileLauncherPackages = lib.attrValues profileLaunchers;

    profileDisplayNames = {
      work = "LibreWolf";
      strict = "LibreWolf Strict";
      compatibility = "LibreWolf Compatibility";
      development = "LibreWolf Development";
    };

    profileBadges = {
      strict = {
        letter = "S";
        lightColor = "#E53935";
        darkColor = "#C62828";
      };
      compatibility = {
        letter = "C";
        lightColor = "#FFB300";
        darkColor = "#F57C00";
      };
      development = {
        letter = "D";
        lightColor = "#7E57C2";
        darkColor = "#5E35B1";
      };
    };

    iconVariants = [
      {
        size = 16;
        badgeSize = 8;
        borderWidth = 1;
        padding = 3;
        macSourceSize = 32;
        solid = true;
      }
      {
        size = 24;
        badgeSize = 10;
        borderWidth = 1;
        padding = 4;
        macSourceSize = 32;
        solid = true;
      }
      {
        size = 32;
        badgeSize = 13;
        borderWidth = 1;
        padding = 5;
        macSourceSize = 32;
        solid = true;
      }
      {
        size = 48;
        badgeSize = 16;
        borderWidth = 1;
        padding = 7;
        macSourceSize = 64;
        solid = false;
      }
      {
        size = 64;
        badgeSize = 20;
        borderWidth = 2;
        padding = 9;
        macSourceSize = 64;
        solid = false;
      }
      {
        size = 128;
        badgeSize = 36;
        borderWidth = 3;
        padding = 18;
        macSourceSize = 128;
        solid = false;
      }
      {
        size = 256;
        badgeSize = 72;
        borderWidth = 6;
        padding = 37;
        macSourceSize = 256;
        solid = false;
      }
      {
        size = 512;
        badgeSize = 144;
        borderWidth = 12;
        padding = 74;
        macSourceSize = 512;
        solid = false;
      }
      {
        size = 1024;
        badgeSize = 288;
        borderWidth = 24;
        padding = 148;
        macSourceSize = 1024;
        solid = false;
      }
    ];

    mkProfileIcon = profile: badge:
      pkgs.runCommand "librewolf-${profile}-icon" {
        nativeBuildInputs =
          [pkgs.imagemagick]
          ++ lib.optionals pkgs.stdenv.isDarwin [pkgs.libicns];
      } ''
        mkdir -p work/source "$out/share"

        ${lib.optionalString pkgs.stdenv.isDarwin ''
          ${pkgs.libicns}/bin/icns2png \
            -x -o work/source \
            ${config.programs.librewolf.finalPackage}/Applications/LibreWolf.app/Contents/Resources/firefox.icns
        ''}

        ${lib.concatMapStringsSep "\n" (
            variant: let
              inherit (variant) size badgeSize borderWidth padding macSourceSize solid;
              scale = 4;
              canvasSize = badgeSize * scale;
              center = canvasSize / 2;
              radius = center - borderWidth * scale;
              strokeWidth = borderWidth * scale;
              pointSize = builtins.floor (canvasSize * 0.58);
              badgeFill =
                if solid
                then "xc:${badge.darkColor}"
                else "gradient:${badge.lightColor}-${badge.darkColor}";
              baseIcon =
                if pkgs.stdenv.isDarwin
                then "work/source/firefox_${toString macSourceSize}x${toString macSourceSize}x32.png"
                else "${config.gtk.iconTheme.package}/share/icons/${config.gtk.iconTheme.name}/apps/scalable/librewolf.svg";
              iconName = "librewolf-${profile}.png";
            in ''
              iconDir="$out/share/icons/hicolor/${toString size}x${toString size}/apps"
              mkdir -p "$iconDir" work/${toString size}

              magick \
                -background none \
                ${lib.escapeShellArg baseIcon} \
                -resize ${toString size}x${toString size} \
                work/${toString size}/base.png

              magick \
                -size ${toString canvasSize}x${toString canvasSize} \
                ${lib.escapeShellArg badgeFill} \
                \( \
                  -size ${toString canvasSize}x${toString canvasSize} \
                  canvas:none \
                  -fill white \
                  -draw "circle ${toString center},${toString center} ${toString (center + radius)},${toString center}" \
                \) \
                -alpha off \
                -compose CopyOpacity \
                -composite \
                -fill none \
                -stroke white \
                -strokewidth ${toString strokeWidth} \
                -draw "circle ${toString center},${toString center} ${toString (center + radius)},${toString center}" \
                work/${toString size}/badge-base.png

              magick \
                -background none \
                -fill white \
                -font ${pkgs.rubik}/share/fonts/truetype/Rubik-Bold.ttf \
                -pointsize ${toString pointSize} \
                label:${lib.escapeShellArg badge.letter} \
                -trim \
                +repage \
                work/${toString size}/letter.png

              magick \
                work/${toString size}/badge-base.png \
                work/${toString size}/letter.png \
                -gravity center \
                -composite \
                -resize ${toString badgeSize}x${toString badgeSize} \
                work/${toString size}/badge.png

              magick \
                work/${toString size}/base.png \
                work/${toString size}/badge.png \
                -gravity southeast \
                -geometry +${toString padding}+${toString padding} \
                -composite \
                "$iconDir/${iconName}"
            ''
          )
          iconVariants}

        ${lib.optionalString pkgs.stdenv.isDarwin ''
          iconset=work/librewolf-${profile}.iconset
          mkdir -p "$iconset"

          cp "$out/share/icons/hicolor/16x16/apps/librewolf-${profile}.png" "$iconset/icon_16x16.png"
          cp "$out/share/icons/hicolor/32x32/apps/librewolf-${profile}.png" "$iconset/icon_16x16@2x.png"
          cp "$out/share/icons/hicolor/32x32/apps/librewolf-${profile}.png" "$iconset/icon_32x32.png"
          cp "$out/share/icons/hicolor/64x64/apps/librewolf-${profile}.png" "$iconset/icon_32x32@2x.png"
          cp "$out/share/icons/hicolor/128x128/apps/librewolf-${profile}.png" "$iconset/icon_128x128.png"
          cp "$out/share/icons/hicolor/256x256/apps/librewolf-${profile}.png" "$iconset/icon_128x128@2x.png"
          cp "$out/share/icons/hicolor/256x256/apps/librewolf-${profile}.png" "$iconset/icon_256x256.png"
          cp "$out/share/icons/hicolor/512x512/apps/librewolf-${profile}.png" "$iconset/icon_256x256@2x.png"
          cp "$out/share/icons/hicolor/512x512/apps/librewolf-${profile}.png" "$iconset/icon_512x512.png"
          cp "$out/share/icons/hicolor/1024x1024/apps/librewolf-${profile}.png" "$iconset/icon_512x512@2x.png"

          /usr/bin/iconutil \
            -c icns \
            -o "$out/share/librewolf-${profile}.icns" \
            "$iconset"
        ''}
      '';

    profileIcons = lib.mapAttrs mkProfileIcon profileBadges;
    profileIconPackages = lib.attrValues profileIcons;

    browserMimeTypes = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];

    profileDesktopEntries =
      lib.mapAttrs' (
        profile: launcher:
          lib.nameValuePair
          (
            if profile == "work"
            then "librewolf"
            else "librewolf-${profile}"
          )
          {
            name = profileDisplayNames.${profile};
            genericName = "Web Browser";
            exec = "${lib.getExe launcher} %U";
            icon =
              if profile == "work"
              then "librewolf"
              else "librewolf-${profile}";
            terminal = false;
            categories = ["Network" "WebBrowser"];
            mimeType = browserMimeTypes;
          }
      )
      profileLaunchers;

    macOSProfileNames = [
      "strict"
      "compatibility"
      "development"
    ];

    mkMacOSProfileApp = profile:
      pkgs.runCommand "librewolf-${profile}-app" {} ''
        app="$out/Applications/${profileDisplayNames.${profile}}.app"
        mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

        cp \
          ${profileIcons.${profile}}/share/librewolf-${profile}.icns \
          "$app/Contents/Resources/librewolf.icns"

        cat > "$app/Contents/Info.plist" <<'EOF'
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleDisplayName</key>
          <string>${profileDisplayNames.${profile}}</string>
          <key>CFBundleExecutable</key>
          <string>librewolf-${profile}</string>
          <key>CFBundleIconFile</key>
          <string>librewolf</string>
          <key>CFBundleIdentifier</key>
          <string>org.nixos.librewolf.profile.${profile}</string>
          <key>CFBundleName</key>
          <string>${profileDisplayNames.${profile}}</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
        </dict>
        </plist>
        EOF

        cat > "$app/Contents/MacOS/librewolf-${profile}" <<'EOF'
        #!${pkgs.runtimeShell}
        exec ${lib.getExe profileLaunchers.${profile}} "$@"
        EOF
        chmod +x "$app/Contents/MacOS/librewolf-${profile}"
      '';

    macOSProfileApps = lib.optionals pkgs.stdenv.isDarwin (
      map mkMacOSProfileApp macOSProfileNames
    );
  in
    lib.mkMerge [
      {
        programs.librewolf = {
          enable = true;
          settings."widget.use-xdg-desktop-portal.file-picker" = 1;
          inherit profiles;
        };

        home.packages =
          profileLauncherPackages
          ++ profileIconPackages
          ++ macOSProfileApps;
      }

      # ---------------------------------
      # Default browser (Linux: XDG)
      # ---------------------------------
      # Linux: register LibreWolf as the default browser via XDG mimeapps.
      (lib.mkIf pkgs.stdenv.isLinux {
        xdg = {
          desktopEntries = profileDesktopEntries;
          mimeApps = {
            enable = true;
            defaultApplications = {
              "text/html" = "librewolf.desktop";
              "application/xhtml+xml" = "librewolf.desktop";
              "x-scheme-handler/http" = "librewolf.desktop";
              "x-scheme-handler/https" = "librewolf.desktop";
              "x-scheme-handler/about" = "librewolf.desktop";
              "x-scheme-handler/unknown" = "librewolf.desktop";
            };
          };
        };
      })

      # ---------------------------------
      # Default browser (macOS: duti)
      # ---------------------------------
      # macOS: LaunchServices has no declarative option, so point the default
      # web/HTML handlers at LibreWolf's bundle id with duti. http/https/html are
      # protected types, so any programmatic `duti -s` pops macOS's anti-hijacking
      # confirmation modal. Guard on the current handler so we only call duti when
      # it isn't already LibreWolf -- the modal then appears at most once per type
      # (on first switch), not on every rebuild.
      (lib.mkIf pkgs.stdenv.isDarwin {
        home.packages = [pkgs.duti];
        home.activation.librewolfDefaultBrowser = lib.hm.dag.entryAfter ["writeBoundary"] ''
          for type in http https public.html; do
            if [ "$(${lib.getExe pkgs.duti} -d "$type" 2>/dev/null)" != "org.nixos.librewolf" ]; then
              $DRY_RUN_CMD ${lib.getExe pkgs.duti} -s org.nixos.librewolf "$type" all || true
            fi
          done
        '';
      })
    ];
}
