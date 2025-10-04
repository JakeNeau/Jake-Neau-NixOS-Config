{ config, pkgs, lib, ... }:

{
  home.username = "jakeneau";
  home.homeDirectory = "/home/jakeneau";

  # link the configuration file in current directory to the specified location in home directory
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  # link all files in `./scripts` to `~/.config/i3/scripts`
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true;   # link recursively
  #   executable = true;  # make all files executable
  # };

  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
  ];

  # Themes for gtk (most apps)
  gtk = {
    iconTheme = {
      package = pkgs.candy-icons;
      name = "candy-icons";
    };
  };

  # basic configuration of git, please change to your own
  programs.git = {
    enable = true;
    userName = "Jake Neau";
    userEmail = "jakeneau@proton.me";
  };

  programs.eza = {
    enable = true;
    colors = "always";
    icons = "always";
    enableFishIntegration = true;
    extraOptions = [
      "--group-directories-first"
    ];
  };

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # Change the keyboard configuration options
      input = {
        kb_options = [
          "ctrl:nocaps"
        ];
      };
      # Enable programs on startup
      exec-once = [
        "hyprpaper"
      ];
      # Monitors
      monitor = [
        "DP-1, 5120x1440@240, 0x0, 1"
      ];

      # Programs
      "$terminal" = "ghostty";
      "$menu" = "fuzzel --fuzzy-max-length-discrepancy=4";

      # Keys
      "$mod" = "SUPER"; # Windows key on most keyboards
      bind = [
        "$mod, Q, exec, $terminal"
	"$mod, C, killactive"
	"$mod, M, exit"
	"$mod, F, fullscreen"
        "$mod, W, togglefloating"
	"$mod, SPACE, exec, $menu"
	"$mod, P, pseudo"
        "$mod, S, togglesplit"
	"$mod, H, movefocus, l"
        "$mod, J, movefocus, d"
	"$mod, K, movefocus, u"
	"$mod, L, movefocus, r"
      ] ++ (
        # Dynamically generate workspaces bindings
        builtins.concatLists (builtins.genList (i:
            let ws = i + 1;
            in [
              "$mod, code:1${toString i}, workspace, ${toString ws}"
              "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
            ]
          )
          9)
      );

      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
	", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ", XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
      ];

      bindl = [
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
      ];
      };
  };

  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      background-opacity = 0.8;
    };
  };

  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
      ipc = true;

      preload = [
        "${config.stylix.image}"
      ];

      wallpaper = [
        "DP-1, ${config.stylix.image}"
      ];
    };
  };

  programs.librewolf = {
    enable = true;
    settings = {
      "privacy.clearOnShutdown.cookies" = false;
      "privacy.clearOnShutdown_v2.cookiesAndStorage" = false;
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
	      urls = [{
	        template = "https://search.brave.com/search";
	        params = [
                  { name = "source"; value = "web"; }
                  { name = "q"; value = "{searchTerms}"; }
	        ];
	      }];
	      icon = "https://upload.wikimedia.org/wikipedia/commons/d/da/Brave_search_logo.png";
	      definedAliases = [ "@b" ];
	    };

	    "home-manager" = {
              name = "Home Manager Options";
              urls = [{
                template = "https://home-manager-options.extranix.com";
                params = [
                  { name = "release"; value = "master"; }
                  { name = "query"; value = "{searchTerms}"; }
                ];
              }];
              iconMapObj."16" = "https://wiki.nixos.org/favicon.ico";
              definedAliases = [ "@ho" ];
	    };

            "nix-options" = {
              name = "Nix Options";
              urls = [{
                template = "https://search.nixos.org/options";
                params = [
                  { name = "sort"; value = "relevance"; }
                  { name = "channel"; value = "unstable"; }
                  { name = "type"; value = "packages"; }
                  { name = "query"; value = "{searchTerms}"; }
                ];
              }];
              icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@no" ];
            };

	    "nix-packages" = {
              name = "Nix Packages";
              urls = [{
                template = "https://search.nixos.org/packages";
                params = [
                  { name = "type"; value = "packages"; }
                  { name = "channel"; value = "unstable"; }
                  { name = "query"; value = "{searchTerms}"; }
                ];
              }];
              icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@np" ];
            };

            "nixos-wiki" = {
              name = "NixOS Wiki";
              urls = [{ template = "https://wiki.nixos.org/w/index.php?search={searchTerms}"; }];
              iconMapObj."16" = "https://wiki.nixos.org/favicon.ico";
              definedAliases = [ "@nw" ];
            };

	    "wikipedia" = {
	      name = "Wikipedia";
	      urls = [{
	        template = "https://en.wikipedia.org/wiki/{searchTerms}";
	      }];
	      icon = "https://upload.wikimedia.org/wikipedia/en/8/80/Wikipedia-logo-v2.svg";
	      definedAliases = [ "@w" ];
	    };
	  };
	};
	extensions = {
	  force = true;
	  packages = with pkgs.nur.repos.rycee.firefox-addons; [
	    bitwarden
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
              tags = [ "wiki" "nix" ];
	      url = "https://wiki.nixos.org/";
	    }
	    {
              name = "Toolbar Bookmarks";
	      toolbar = true;
	      bookmarks = [
                {
                  name = "Nixos Wiki";
                  tags = [ "Wiki" "Nix" ];
                  url = "https://wiki.nixos.org/";
                }
		{
                  name = "Rust";
	          tags = [ "documentation" ];
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
  stylix.targets.librewolf.profileNames = [ "default" ];

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
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
  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";
}
