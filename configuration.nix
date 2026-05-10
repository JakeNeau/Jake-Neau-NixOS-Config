{
  config,
  pkgs,
  lib,
  ...
}: {
  nix.settings = {
    # Experimental nix settings
    experimental-features = ["nix-command" "flakes"];

    # Other nix settings
    warn-dirty = false;
  };

  # direnv will load nix configs automatically in project folders
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  imports = [
    ./hardware-configuration.nix
  ];

  # Files for secrets management
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/etc/nixos/secrets/keys.txt";
    secrets.hashedPasswordJakeNeau.neededForUsers = true;
  };

  # Bootloader.
  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      minegrub-theme = {
        enable = true;
        splash = "I use NixOS BTW!!";
        background = "background_options/1.8  - [Classic Minecraft].png";
        boot-options-count = 4;
      };
      gfxmodeEfi = "5120x1440";
      gfxmodeBios = "5120x1440";
      extraEntries = ''
        menuentry "Windows 11 (Skill Issue)" {
          search --fs-uuid --no-floppy --set=root 4443-0F45
          chainloader (''\${root})/EFI/Microsoft/Boot/bootmgfw.efi
        }
        menuentry "UEFI Firmware Settings" {
          fwsetup
        }
      '';
      extraConfig = ''
        GRUB_TIMEOUT=10
      '';
    };
  };
  stylix.targets.grub.enable = false;

  boot.kernelParams = ["video=5120x1440"];

  boot.kernelPatches = [
    {
      # Patches for running steamVR
      name = "amdgpu-ignore-ctx-privileges";
      patch = pkgs.fetchpatch {
        name = "cap_sys_nice_begone.patch";
        url = "https://github.com/Frogging-Family/community-patches/raw/master/linux61-tkg/cap_sys_nice_begone.mypatch";
        hash = "sha256-Y3a0+x2xvHsfLax/uwycdJf3xLxvVfkfDVqjkxNaYEo=";
      };
    }
  ];

  boot.initrd.luks.devices."luks-014e6aef-d36f-4b5b-9b48-447d6bc40b95".device = "/dev/disk/by-uuid/014e6aef-d36f-4b5b-9b48-447d6bc40b95";
  networking.hostName = "nixos"; # Define your hostname.

  # Set the wireless daemon
  networking.wireless.iwd = {
    enable = true;
    settings = {
      IPv6 = {
        Enabled = true;
      };
      Settings = {
        AutoConnect = true;
      };
    };
  };

  # Enable networking
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
  };

  # Bluetooth settings
  hardware.bluetooth.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Compositor: displays the desktop
  programs.niri.enable = true;

  # Enable other desktop portals
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  # Configure keymap
  services.xserver.xkb = {
    layout = "us";
    variant = "";
    options = "ctrl:nocaps";
  };
  console.useXkbConfig = true;

  # Enable CUPS to print documents.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      cups-filters
      cups-browsed
    ];
  };

  # Configure hardware settings for AMD GPUs
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # Needed for Davinci Resolve
      rocmPackages.clr.icd
      mesa.opencl
    ];
  };
  nixpkgs.config.rocmSupport = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    extraConfig.pipewire = {
      "91-null-sinks" = {
        "context.objects" = [
          {
            factory = "adapter";
            args = {
              "factory.name" = "support.null-audio-sink";
              "node.name" = "Multi-Output";
              "node.desctiption" = "Replicates output to multiple sinks";
              "media.class" = "Audio/Sink";
              "audio.position" = "FL,FR";
            };
          }
        ];
      };
      #      Evil ass low latency audio script, turning it on kills my sound output
      #      "92-low-latency" = {
      #        "context.properties" = {
      #          "default.clock.rate" = 48000;
      #          "default.clock.quantum" = 32;
      #          "default.clock.min-quantum" = 32;
      #          "default.clock.max-quantum" = 32;
      #        };
      #      };
    };
  };

  # Run pipewire setup scripts on startup
  systemd.user.services.create-pipewire-links = {
    description = "create-pipewire-links: sets up pipewire connections after pipewire is set up";
    wantedBy = [
      "pipewire.service"
    ];
    requires = [
      "pipewire.service"
      "wireplumber.service"
    ];
    after = [
      "pipewire.service"
      "wireplumber.service"
    ];
    preStart = "sleep 5";
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 5;
    };
    script = ''
      # ports obtained from `pw-link -io`

      # Connect multi-output to focusrite headphones
      /run/current-system/sw/bin/pw-link "Multi-Output:monitor_FL" "alsa_output.usb-Focusrite_Scarlett_2i2_USB_Y8XBPE40BA5F9E-00.HiFi__Line1__sink:playback_FL"
      /run/current-system/sw/bin/pw-link "Multi-Output:monitor_FR" "alsa_output.usb-Focusrite_Scarlett_2i2_USB_Y8XBPE40BA5F9E-00.HiFi__Line1__sink:playback_FR"

      # Connect multi-output to fiio amp
      /run/current-system/sw/bin/pw-link "Multi-Output:monitor_FL" "alsa_output.usb-GuangZhou_FiiO_Electronics_Co._Ltd_FiiO_K7-00.analog-stereo:playback_FL"
      /run/current-system/sw/bin/pw-link "Multi-Output:monitor_FR" "alsa_output.usb-GuangZhou_FiiO_Electronics_Co._Ltd_FiiO_K7-00.analog-stereo:playback_FR"
    '';
  };

  # User accounts
  users.mutableUsers = false;
  users.users.jakeneau = {
    isNormalUser = true;
    description = "Jake Neau";
    extraGroups = ["networkmanager" "wheel"];
    hashedPasswordFile = config.sops.secrets.hashedPasswordJakeNeau.path;
  };

  # Set users of the wheel group to not need sudo passwords
  security.sudo.wheelNeedsPassword = false;

  # Enable polkit for running privledged operations
  security.polkit.enable = true;

  # Greeter: handles login
  services.greetd = {
    enable = true;
    settings = rec {
      initial_session = {
        command = "${pkgs.niri}/bin/niri-session -l";
        user = "jakeneau";
      };
      default_session = initial_session;
    };
  };

  # Enable Gnome Keyring for staying logged into applications
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Default version control software
  programs.git = {
    enable = true;
    config = {
      user.name = "Jake Neau";
      user.email = "jakeneau@proton.me";
      init.defaultBranch = "main";
      safe.directory = "/etc/nixos";
    };
  };

  # Declarative Neovim distribution
  programs.nvf = {
    enable = true;
    defaultEditor = true;

    settings.vim = {
      viAlias = true;
      vimAlias = true;

      # Turn off the annoying notification sound on invalid actions
      bell = "none";

      # Set the clipboard so the unnamed register is the system clipboard
      clipboard = {
        enable = true;
        registers = "unnamedplus";
      };

      # Diagnostics for plugins to communicate error states
      diagnostics = {
        enable = true;
        config = {
          signs = true;
          underline = true;
          update_in_insert = false;
          virtual_lines = true;
        };
      };

      # Cache lua bytecode for faster launches
      enableLuaLoader = true;

      # Set leader key for shortcuts (space is common)
      globals.mapleader = " ";

      # Set leader key for buffer-local mappings
      globals.maplocalleader = "\\";

      # Pressing escape clears all highlighted search results
      hideSearchHighlight = true;

      # How to display the line number for the current line
      lineNumberMode = "relNumber";

      # Store intermediate files in XDG compliant location to keep work dir clean
      preventJunkFiles = true;

      # How to do a search, smart means case insensitive unless there is any upper case
      searchCase = "smart";

      # Fallback syntax highlighting when treesitter is not avaliable
      syntaxHighlighting = true;

      # Persist undo state across opening and closing neovim
      undoFile.enable = true;

      # ----------------
      # Global Options
      # ----------------
      options = {
        autoindent = true; # Automatically indent on a newline
        cmdheight = 1; # The height of the command pane in lines
        cursorlineopt = "both"; # The way to highlight the line the cursor is on
        foldlevel = 99; # stops auto folding when opening document
        mouse = "nvi"; # Supported modes for mouse control
        shiftwidth = 0; # Number of spaces to use for autoindent, 0 means use tabstop vaule
        signcolumn = "yes"; # Show the sign column (what is sign column)
        splitbelow = true; # On true new splits open below instead of above
        splitright = true; # New splits will open to the right
        tabstop = 2; # The number of spaces a tab counts for
        termguicolors = true; # On true use 256 colors for terminal
        tm = 500; # The time in ms that Neovim will wait for the next key in chord
        updatetime = 25; # The number of ms until the cursor hold event is triggered
        wrap = false; # Whether to wrap lines if they go off screen
      };

      # ---------------------------------------
      # Lazy Loading and non-included plugins
      # ---------------------------------------
      lazy = {
        enable = true; # Enable lazy loading for plugins to load in only when needed
        enableLznAutoRequire = true; # Builtin plugins need this, only turn off for debug
        plugins = {
          "pi.nvim" = {
            package = pkgs.vimPlugins.pi-nvim;
            setupModule = "pi";
            setupOpts = {
              provider = "openai-codex";
              model = "gpt-5.5";
              thinking = "off";
            };
            cmd = ["PiAsk" "PiAskSelection"];

            keys = [
              {
                key = "<leader>ai";
                mode = "n";
                action = "<cmd>PiAsk<cr>";
                desc = "Ask pi";
              }
              {
                key = "<leader>ai";
                mode = "v";
                action = "<cmd>PiAskSelection<cr>";
                desc = "Ask pi with current selection";
              }
            ];
          };
        };
      };

      # ------------------
      # Language Support
      # ------------------
      languages = {
        enableFormat = true;
        enableTreesitter = true;
        enableExtraDiagnostics = true;

        bash.enable = true;

        clang.enable = true;

        css.enable = true;

        dart = {
          enable = true;
          dap.enable = true;
          flutter-tools.enable = true;
        };

        go.enable = true;

        html.enable = true;

        java.enable = true;

        json.enable = true;

        lua = {
          enable = true;
          lsp.lazydev.enable = true; # Extra config for NeoVim Files
        };

        markdown = {
          enable = true;
          extensions.render-markdown-nvim.enable = true; # Inline markdown rendering
        };

        nix = {
          enable = true;
          format.type = ["alejandra"];
          lsp.servers = ["nil"];
        };

        python = {
          enable = true;
          lsp.servers = ["pyright"];
          format.type = ["black"];
        };

        rust = {
          enable = true;
          extensions.crates-nvim.enable = true;
        };

        toml.enable = true;

        # Both JavaScript and TypeScript
        typescript = {
          enable = true;
          format.type = ["prettier"];
        };

        yaml.enable = true;
      };

      # ---------
      # Lualine
      # ---------
      statusline.lualine = {
        enable = true;
        setupOpts.sections.lualine_c = [
          (lib.generators.mkLuaInline ''
            function()
              if vim.bo.filetype == "oil" then
                local ok, oil = pcall(require, "oil")
                if ok then
                  local dir = oil.get_current_dir()
                  if dir then
                    return vim.fn.fnamemodify(dir, ":~")
                  end
                end
              end
              return "%f"
            end
          '')
        ];

        setupOpts.sections.lualine_b = [
          (lib.generators.mkLuaInline ''
            function()
              if vim.bo.filetype == "oil" then
                return ""
              end
              local name = vim.fn.expand("%:~:.")
              return vim.fs.basename(name)
            end
          '')
        ];
      };

      # ---------------------
      # Global LSP Behavior
      # ---------------------
      lsp = {
        enable = true;
        formatOnSave = true;

        # Pretty icons next to completion items
        lspkind.enable = true;

        # Enhanced LSP UI
        lspsaga = {
          enable = true;
          # mappings = {
          #   codeAction = "<leader>ca";
          #   definiton = "gd";
          #   hover = "K";
          #   rename = "<leader>rn";
          # };
        };

        # Inline Errors
        trouble.enable = true;

        # Function signature help popup
        nvim-docs-view.enable = true;
      };

      # ------------
      # Treesitter
      # ------------
      treesitter = {
        enable = true; # Use a full syntax tree for parser
        fold = true; # Use treesitter for folding text (collapse)
        addDefaultGrammars = true; # A set of starter grammars
        autotagHtml = true; # Automatically add matching closing tags to HTML

        # Function and class headers at the top
        context = {
          enable = true;
          setupOpts.max_lines = 4;
        };

        textobjects = {
          enable = true;
          setupOpts = {
            # Move between functions and classes
            move = {
              enable = true;
              gotoNextStart = {
                "]m" = "@function.outer";
                "]]" = "@class.outer";
              };
              gotoPreviousStart = {
                "[m" = "@function.outer";
                "[[" = "@class.outer";
              };
            };

            # Select blocks of code semantically
            select = {
              enable = true;
              lookahead = true;
              keymaps = {
                "af" = "@function.outer";
                "if" = "@function.inner";
                "ac" = "@class.outer";
                "ic" = "@class.inner";
                "aa" = "@parameter.outer";
                "ia" = "@parameter.inner";
              };
            };
          };
        };
      };

      # ------------
      # Completion
      # ------------
      autocomplete.nvim-cmp = {
        enable = true;

        mappings = {
          confirm = "<CR>";
          next = "<Tab>";
          previous = "<S-Tab>";
          scrollDocsUp = "<C-b>";
          scrollDocsDown = "<C-f>";
          complete = "<C-Space>";
        };
      };

      # ---------------------------------
      # Snippets for custom completions
      # ---------------------------------
      snippets.luasnip = {
        enable = true;
        providers = ["friendly-snippets"];
      };

      # -----------
      # Telescope
      # -----------
      telescope = {
        enable = true;
        mappings = {
          findFiles = "<leader>ff";
          liveGrep = "<leader>fg";
          buffers = "<leader>fb";
          helpTags = "<leader>fh";
          diagnostics = "<leader>fd";
          lspReferences = "<leader>fr";
          lspDefinitions = "<leader>fD";
          gitCommits = "<leader>gc";
          gitBranches = "<leader>gb";
        };
      };

      # ---------------
      # File Explorer
      # ---------------
      utility.oil-nvim = {
        enable = true;
        gitStatus.enable = true;
        setupOpts = {
          keymaps = {
            "<C-h>" = false;
            "<C-l>" = false;
            "<C-r>" = "actions.refresh";
            "<C-w><CR>" = "actions.select_vsplit";
            "<C-w><C-CR>" = "actions.select_split";
          };
        };
      };

      # -----------
      # Dashboard
      # -----------
      dashboard.alpha = {
        enable = true;
      };

      # ---------------
      # Other keymaps
      # ---------------
      keymaps = [
        {
          key = "<C-h>";
          mode = "n";
          action = "<C-w>h";
          desc = "Move right one window";
        }
        {
          key = "<C-j>";
          mode = "n";
          action = "<C-w>j";
          desc = "Move down one window";
        }
        {
          key = "<C-k>";
          mode = "n";
          action = "<C-w>k";
          desc = "Move up one window";
        }
        {
          key = "<C-l>";
          mode = "n";
          action = "<C-w>l";
          desc = "Move left one window";
        }
        {
          key = "-";
          mode = "n";
          action = "<cmd>Oil<cr>";
          desc = "Open oil (parent directory)";
        }
      ];
    };
  };

  # PC game platform
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  # A TUI file browser
  programs.yazi = {
    enable = true;
  };

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
    vscode
    audacity # Audio recording program
    bitwarden-desktop # Password manager for all devices
    blender # 3D Modeling art program with AMD GPU support (hip)
    bluetui # A tui for managing bluetooth
    # (bottles.override {
    #   # A wine prefix manager
    #   removeWarningPopup = true;
    # })
    bottom # A TUI system monitor
    candy-icons # A gradient vector icon theme
    clipse # A cool clipboard manager
    ckan # A mod manager for Kerbal Space Program
    davinci-resolve-studio # Professional video editor
    element-desktop # A group messaging service with an open source API
    eza # A better version of ls written in rust
    fastfetch # Terminal program for displaying system info and flexing on arch users
    ffmpeg # Video codec
    freecad # An open source parametric 3D modeling program
    fishPlugins.colored-man-pages # More interesting man pages
    fishPlugins.fish-bd # Go back directories with bd
    fishPlugins.fzf-fish # Search for multiple things with fzf
    fishPlugins.grc # A generic colorizer
    fishPlugins.pisces # Adds parentheses, quotes, etc. in pairs
    fishPlugins.plugin-sudope # Add sudo to a command when you forgot
    fishPlugins.puffer # Useful text expansions
    fishPlugins.pure # Minimal and fast fish prompt
    fishPlugins.sponge # Remove typos from terminal
    fishPlugins.z # Jump to previous directories
    fuzzel # Super fast application launcher
    fzf # System wide fuzzy finder
    ghostty # A fast and GPU accelerated terminal emulator
    gnucash # Double-entry accounting software
    grc # Generic text colorizer
    hunspell # Spell check needed for LibreOffice
    hunspellDicts.en_US # US English dictionary for Hunspell
    inkscape # Vector graphics editor
    jdk21 # Java Development Kit
    jujutsu # A better VCS built on top of git
    krita # A FOSS art program
    libreoffice-qt-fresh # A FOSS office suite
    librewolf # Firefox based browser with more privacy
    mpv # General purpose video player
    obs-studio # Screen recording software
    obsidian # Note taking utility using markdown files
    papirus-icon-theme # Fallback icon set
    pavucontrol # Sound setting control GUI
    playerctl # Keyboard controls for audio players
    prismlauncher # Minecraft launcher
    loupe # Fast and lightweight image viewer
    qpwgraph # A patchbay and volume control program that works with pipewire
    reaper # A configurable digital audio workstation
    sops # CLI tools for secrets management
    signal-desktop # A private messaging service
    spotify # Music subscription service
    swaybg # Wallpaper utility
    tldr # Summarize man pages for commands
    todoist-electron # Todo tracker app
    udiskie # Automounting for removable media
    ungoogled-chromium # Chromium without all the callbacks to google
    unzip # CLI file unzipping
    vesktop # Alternative to discord messaging app
    wget # Download web files from the command line
    wl-clip-persist # Make sure clipboard items persist after programs close
    wl-clipboard # Clipboard manager backend
    xournalpp # App for signing PDFs
    xwayland-satellite # Xwayland compatability for wayland only compositors
    yaziPlugins.gvfs # Mount devices to a VFS in yazi
  ];

  # Set default applications
  xdg.mime = {
    enable = true;
    defaultApplications = {
      "inode/directory" = "yazi.desktop";
    };
  };

  # Fonts
  fonts = {
    packages = with pkgs; [
      google-fonts
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      liberation_ttf
    ];
    fontDir.enable = true;
  };

  # RGB control software
  services.hardware.openrgb = {
    enable = true;
    startupProfile = "orange";
  };

  # Environment varables set on shell init
  environment.variables = {
    NIX_ROOT = "/etc/nixos";
    RUSTICL_ENABLE = "radeonsi";
  };

  programs.bash = {
    enable = true;
    interactiveShellInit = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };
  programs.fish = {
    enable = true;
    shellAliases = {
      # NixOS Aliases
      nf = "suu git -C /etc/nixos pull 1>/dev/null; sudoedit /etc/nixos/flake.nix";
      nc = "suu git -C /etc/nixos pull 1>/dev/null; sudoedit /etc/nixos/configuration.nix";
      nh = "suu git -C /etc/nixos pull 1>/dev/null; $EDITOR /etc/nixos/users/$USER/home.nix";
      ng = "sudo nix-collect-garbage --delete-old";
      ns = "suu git -C /etc/nixos pull 1>/dev/null; sops /etc/nixos/secrets/secrets.yaml";

      # Git aliases
      ga = "git add";
      gc = "git commit -m";
      gp = "git push";

      # General Command Aliases
      ls = "eza --icons --group-directories-first";
      l = "eza-long"; # This is needed because the function 'eza-long' will not override the fish default 'l' function if named 'l'
      r = "sudo systemctl reboot";
      s = "sudo systemctl poweroff";
    };
    shellInit = ''
      # Clean up all failed commands from history after 20 entries
      set sponge_delay 20

      function fish_greeting --description "What to run when fish starts up every time"
        fastfetch
      end

      function suu --description "Run sudo as the current user"
        sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" $argv
      end

      function npd --description "Nix Package Describe: builds a nix package and lists the contents inside of it at the specified tree level"
        argparse -- $argv
        or return 1
        if test (count $argv) -gt 2
          echo "Error: expected at most two arguments but got " (count $argv)
          echo "Usage: npd <package> [tree-level]"
          return 1
        end

        set -l package_name $argv[1]

        set -l tree_level 4
        if test (count $argv) -eq 2
          set tree_level $argv[2..-1]
        end

        npr $package_name "l $tree_level | less"
        or return 1
      end

      function npv --description "Nix Package View: enter an editor for a single file in the desired nix package"
        argparse -- $argv
        or return 1
        if test (count $argv) -ne 2
          echo "Error: expected two arguments but got " (count $argv)
          echo "Usage: npv <package> <file>"
          return 1
        end

        set -l package_name $argv[1]
        set -l file $argv[2]

        npr $package_name less $file
      end

      function npr --description "Nix Package Run: builds a nix package and runs the specified command from the package root"
        argparse -- $argv
        or return 1

        if test (count $argv) -lt 2
          echo "Error: expected at least 2 arguments but got " (count $argv)
          echo "Usage: npr <package> <command>"
          return 1
        end

        set -l package_name $argv[1]
        set -l command $argv[2..-1]
        set -l start_directory (pwd)

        nix build nixpkgs#$package_name
        or return 1
        mv result package-build-result
        cd package-build-result
        eval $command
        cd $start_directory
        rm -rf package-build-result
        or return 1
      end

      function nrr --description "Runs the nixos-rebuild alias with a 'regular update' method"
        nr "Regular update"
      end

      function nr --description "Reloads the NixOS config and pushes it to git. If a message is specified, create a new commit"
        argparse 'n/no-git' 'f/full-output' -- $argv
        or return 1

        if set -q _flag_full
          suu git -C /etc/nixos pull
          sudo nix flake update --flake /etc/nixos
          sudo nixos-rebuild switch --upgrade --flake /etc/nixos
          or return 1
        else
          suu git -C /etc/nixos pull 1>/dev/null
          echo "Rebuilding NixOS configuration..."
          sudo nix flake update --flake /etc/nixos --quiet
          sudo nixos-rebuild switch --upgrade --flake /etc/nixos --quiet
          or return 1
        end
        set new_generation (readlink /nix/var/nix/profiles/system | cut -d- -f2)
        echo "NixOS configuration rebuilt for generation $new_generation"

        # Run git commands unless told not to
        if set -q _flag_full
          if not set -q _flag_no_git
            sudo git -C /etc/nixos add -A
            # Amend the last commit with the new generatioin if a message is not specified
            if test (count $argv) -eq 0
              set last_commit_message (git -C /etc/nixos log -1 --pretty=%s)
              if test (string match -r '^Generation [0-9]+:' -- $last_commit_message | count) -gt 0
                set new_commit_message (string replace -r '^Generation [0-9]+:' "Generation $new_generation:" -- $last_commit_message)
              else
                set new_commit_message "Generation $new_generation: $last_commit_message"
              end
              sudo git -C /etc/nixos commit --amend -m "$new_commit_message"
              or return 1
              suu git -C /etc/nixos push --force-with-lease
              or return 1
            # Make a new commit if the message is specified
            else
              set new_commit_message "Generation $new_generation: $argv"
              sudo git -C /etc/nixos commit -m "$new_commit_message"
              or return 1
              sudo git -C /etc/nixos push
              or return 1
            end
          end
        else
          if not set -q _flag_no_git
            sudo git -C /etc/nixos add -A 1>/dev/null
            # Amend the last commit with the new generatioin if a message is not specified
            if test (count $argv) -eq 0
              set last_commit_message (git -C /etc/nixos log -1 --pretty=%s)
              if test (string match -r '^Generation [0-9]+:' -- $last_commit_message | count) -gt 0
                set new_commit_message (string replace -r '^Generation [0-9]+:' "Generation $new_generation:" -- $last_commit_message)
              else
                set new_commit_message "Generation $new_generation: $last_commit_message"
              end
              sudo git -C /etc/nixos commit --amend -qm "$new_commit_message"
              or return 1
              suu git -C /etc/nixos push --force-with-lease -q
              or return 1
            # Make a new commit if the message is specified
            else
              set new_commit_message "Generation $new_generation: $argv"
              sudo git -C /etc/nixos commit -qm "$new_commit_message"
              or return 1
              suu git -C /etc/nixos push -q
              or return 1
            end
            echo "Commit \"$new_commit_message\" pushed to GitHub"
          end
        end
      end

      function eza-long --description "Runs eza with a lot of information"
        set -l depth
        set -l path

        for arg in $argv
          # Set depth if depth is not set and the argument is a number
          if test -z "$depth" -a (string match -r '^[0-9]+$' "$arg" | count) -gt 0
            set depth "$arg"
          else if test -z "$path"
            set path "$arg"
          end
        end

        if not test -z "$depth"
          eza -algh --git-repos --git --icons --group-directories-first -T -L=$depth $path
        else
          eza -algh --git-repos --git --icons --group-directories-first $path
        end
      end

      function g --description "General git function for adding, commiting, and pushing"
        argparse 'f/force' 'a/amend' 'c/current-directory' 'l/long' -- $argv

        if test (count $argv) -eq 0
          set _flag_amend true
        end
        if set -q _flag_amend
          set _flag_force true
        end

        set parse_flags ""
        if not set -q _flag_long
          set parse_flags "$parse_flags --quiet"
        end

        set add_flags ""
        if not set -q _flag_long
          set add_flags "$add_flags 1>/dev/null"
        end

        set commit_flags ""
        if set -q _flag_amend
          set commit_flags "$commit_flags --amend"
        end
        if test (count $argv) -eq 0
          set commit_flags "$commit_flags --no-edit"
        else
          set commit_flags "$commit_flags -m"
        end
        if not set -q _flag_long
          set commit_flags "$commit_flags -q"
        end

        set push_flags ""
        if set -q _flag_force
          set push_flags = "$push_flags --force-with-lease"
        end
        if not set -q _flag_long
          set push_flags = "$push_flags -q"
        end

        if set -q _flag_current-directory
          set git root "."
        else
          set git_root (git rev-parse --show-toplevel $parse_flags)
          or return 1
        end
        set git_all "$git_root/*"

        git add $git_all $add_flags
        or return 1

        git commit $commit_flags $argv
        or return 1

        git push $push_flags
        or return 1
      end

      function mc-list --description "Lists all available minecraft servers in systemd"
        echo "Available servers:"
        for unit in (systemctl list-unit-files --type=service --all --no-legend | grep minecraft-server | awk '{print $1}')
          set name (string replace --regex 'minecraft-server-(.+)\.service' '$1' $unit)
          set server_status (systemctl is-active $unit)
          echo "  $name ($server_status)"
        end
      end

      function mc-start --description "Start the specified minecraft server in systemd"
        if test (count $argv) -eq 0
          echo "Usage: mc-start <server-name>"
          echo ""
          mc-list
          return 1
        end

        set server $argv[1]
        set service "minecraft-server-$server"

        if not systemctl list-unit-files --type=service --all --no-legend | grep -q "$service"
          echo "Error: server '$server' not found"
          echo ""
          mc-list
          return 1
        end

        sudo systemctl start $service

        if test $status -eq 0
            echo "Server '$server' is up"
        else
          echo "Failed to start '$server' -- check logs with: journalctl -u $service -f"
          return 1
        end
      end

      function mc-stop --description "Stop the specified minecraft server in systemd"
        if test (count $argv) -eq 0
          echo "Usage: mc-stop <server-name>"
          echo ""
          mc-list
          return 1
        end

        set server $argv[1]
        set service "minecraft-server-$server"

        if not systemctl list-unit-files --type=service --all --no-legend | grep -q "$service"
          echo "Error: server '$server' not found"
          echo ""
          mc-list
          return 1
        end

        sudo systemctl stop $service

        if test $status -eq 0
          echo "Server '$server' is down"
        else
          echo "Failed to stop '$server' -- check logs with: journalctl -u $service -f"
          return 1
        end
      end

      function mc-logs --description "List the systemd logs for the specified server"
        argparse 'f/follow' -- $argv

        if test (count $argv) -eq 0
          echo "Usage: mc-logs <server-name> [flags]"
          echo "Options:"
          echo "  -f, --follow    Follow log output"
          echo ""
          mc-list
          return 1
        end

        set server $argv[1]
        set service "minecraft-server-$server"

        if not systemctl list-unit-files --type=service --all --no-legend | grep -q "$service"
          echo "Error: server '$server' not found"
          echo ""
          mc-list
          return 1
        end

        if set -q _flag_follow
          journalctl -u $service -f
        else
          journalctl -u $service
        end
      end
    '';
  };

  # Stylix works with home manager to give most apps a consistent styling
  stylix = {
    enable = true;

    # Set color scheme
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-hard.yaml";
    polarity = "dark";

    # Set Wallpaper
    image = ./wallpapers/mountain-sunset.jpg;

    # Set cursor
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };

    # Set fonts
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.lilex;
        name = "Lilex Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
      serif = {
        package = pkgs.zilla-slab;
        name = "Zilla Slab";
      };
    };
  };

  # A decaritively configured minecraft server
  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;

    servers = {
      vanilla-optimized = {
        enable = true;
        autoStart = false;
        package = pkgs.purpurServers.purpur-1_21_11;
      };
    };
  };

  # The first system version installed
  # Do not change unless you know what you are doing, things will break
  system.stateVersion = "24.11";
}
