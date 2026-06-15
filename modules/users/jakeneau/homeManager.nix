{inputs, ...}: {
  # Jake's home environment. Cross-platform core (git, jujutsu, editor, CLI);
  # the Linux/wayland desktop programs are gated to Linux so the same config
  # also evaluates on macOS.
  flake.modules.homeManager.jakeneau = {
    config,
    pkgs,
    lib,
    ...
  }: {
    imports = with inputs.self.modules.homeManager; [
      system-desktop
    ];

    config = lib.mkMerge [
      {
        programs.git = {
          enable = true;
          settings.user = {
            name = "Jake Neau";
            email = "jakeneau@proton.me";
          };
        };

        programs.jujutsu = {
          enable = true;
          settings.user = {
            name = "Jake Neau";
            email = "jakeneau@proton.me";
          };
        };
      }

      (lib.mkIf pkgs.stdenv.isLinux {
        # Themes for gtk (most apps)
        gtk = {
          iconTheme = {
            package = pkgs.candy-icons;
            name = "candy-icons";
          };
        };

        services.clipse = {
          enable = true;
          imageDisplay = {
            type = "kitty";
            scaleX = 9;
            scaleY = 9;
          };
        };

        programs.librewolf = {
          enable = true;
          settings = {
            "widget.use-xdg-desktop-portal.file-picker" = 1; # Use the xdg portal (yazi) for file uploads/saves
            "privacy.clearOnShutdown.cookies" = false;
            "privacy.clearOnShutdown_v2.cookiesAndStorage" = false;
            "privacy.resistFingerprinting.reduceTimerPrecision.jitter" = false; # Needed to make claude not bug out
            "privacy.trackingprotection.allow_list.baseline.enabled" = true;
            "privacy.trackingprotection.allow_list.convenience.enabled" = true;
          };
          profiles = {
            default = {
              id = 0;
              name = "default";
              isDefault = true;
              settings = {
                "extensions.autoDisableScopes" = 0;
                "browser.search.defaultenginename" = "Brave";
                "browser.search.order.1" = "Brave";
              };
              search = {
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
                  "brave" = {
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

                  "home-manager" = {
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

                  "nix-options" = {
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

                  "nix-packages" = {
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

                  "nixos-wiki" = {
                    name = "NixOS Wiki";
                    urls = [{template = "https://wiki.nixos.org/w/index.php?search={searchTerms}";}];
                    iconMapObj."16" = "https://wiki.nixos.org/favicon.ico";
                    definedAliases = ["@nw"];
                  };

                  "wikipedia" = {
                    name = "Wikipedia";
                    urls = [
                      {
                        template = "https://en.wikipedia.org/wiki/{searchTerms}";
                      }
                    ];
                    icon = "https://upload.wikimedia.org/wikipedia/en/8/80/Wikipedia-logo-v2.svg";
                    definedAliases = ["@w"];
                  };
                };
              };
              extensions = {
                force = true;
                packages = with pkgs.nur.repos.rycee.firefox-addons; [
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
                # Find extension ids in about:debugging under This LibreWolf
                settings = {
                  "uBlock0@raymondhill.net" = {
                    force = true;
                    settings = {
                      selectedFilterLists = [
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
                };
              };
              bookmarks = {
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
            };
          };
          policies = {
            ExtensionSettings = {
              # Bitwarden
              "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
                force_installed = true;
                default_area = "menupanel";
                private_browsing = true;
              };
              # Chrome Mask
              "chrome-mask@overengineer.dev" = {
                force_installed = true;
                default_area = "menupanel";
                private_browsing = true;
              };
              # Dark Reader
              "addon@darkreader.org" = {
                force_installed = true;
                default_area = "menupanel";
                private_browsing = true;
              };
              # Don't Fuck With Paste
              "DontFuckWithPaste@raim.ist" = {
                force_installed = true;
                default_area = "menupanel";
                private_browsing = true;
              };
              # Return Youtube Dislikes
              "{762f9885-5a13-4abd-9c77-433dcd38b8fd}" = {
                force_installed = true;
                default_area = "menupanel";
                private_browsing = true;
              };
              # SponsorBlock
              "sponsorBlocker@ajay.app" = {
                force_installed = true;
                default_area = "menupanel";
                private_browsing = true;
              };
              # Tridactyl
              "uBlock0@raymondhill.net" = {
                force_installed = true;
                default_area = "menupanel";
                private_browsing = true;
              };
              # uBlock Origin
              "tridactyl.vim@cmcaine.co.uk" = {
                force_installed = true;
                default_area = "menupanel";
                private_browsing = true;
              };
              # Youtube Shorts Block
              "{34daeb50-c2d2-4f14-886a-7160b24d66a4}" = {
                force_installed = true;
                default_area = "menupanel";
                private_browsing = true;
              };
            };
          };
        };

        programs.fuzzel = {
          enable = true;
          settings = {
            main = {
              terminal = "${pkgs.ghostty}/bin/ghostty -e";
              font = lib.mkForce "monospace:size=24";
              line-height = 60;
              lines = 12;
              match-mode = "fzf";
              tabs = 4;
              use-bold = "true";
              width = 32;
              icon-theme = config.gtk.iconTheme.name;
            };
          };
        };

        # Create files to hide unused fuzzel programs
        home.file = {
          ".local/share/applications/qt5ct.desktop".text = "[Desktop Entry]\nNoDisplay=true";
          ".local/share/applications/qt6ct.desktop".text = "[Desktop Entry]\nNoDisplay=true";
          ".local/share/applications/kvantummanager.desktop".text = "[Desktop Entry]\nNoDisplay=true";
          ".local/share/applications/xterm.desktop".text = "[Desktop Entry]\nNoDisplay=true";
          ".local/share/applications/nvim.desktop".text = "[Desktop Entry]\nNoDisplay=true";
          ".local/share/applications/nixos-manual.desktop".text = "[Desktop Entry]\nNoDisplay=true";
        };
      })
    ];
  };
}
