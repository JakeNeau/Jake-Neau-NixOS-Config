{inputs, ...}: {
  # Coarse "desktop" layer shared by every NixOS workstation (desktop + laptop).
  # First-pass dendritic move: this is intentionally one large module. Split
  # individual features (niri, audio, shell, fonts, …) out of here over time.

  flake.modules.nixos.system-desktop = {
    config,
    pkgs,
    lib,
    ...
  }: {
    imports =
      (with inputs.self.modules.nixos; [
        system-default
        stylix
      ])
      ++ [inputs.self.modules.generic.cli];

    # direnv will load nix configs automatically in project folders
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

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

    # Podman is a container runtime
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

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

    # Enable sound with pipewire.
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
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
      candy-icons # A gradient vector icon theme
      clipse # A cool clipboard manager
      ckan # A mod manager for Kerbal Space Program
      davinci-resolve-studio # Professional video editor
      element-desktop # A group messaging service with an open source API
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
      ghostty # A fast and GPU accelerated terminal emulator
      gnucash # Double-entry accounting software
      hunspell # Spell check needed for LibreOffice
      hunspellDicts.en_US # US English dictionary for Hunspell
      inkscape # Vector graphics editor
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
      signal-desktop # A private messaging service
      spotify # Music subscription service
      swaybg # Wallpaper utility
      todoist-electron # Todo tracker app
      udiskie # Automounting for removable media
      ungoogled-chromium # Chromium without all the callbacks to google
      vesktop # Alternative to discord messaging app
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

    # Environment varables set on shell init
    environment.variables = {
      NIX_ROOT = "/etc/nixos";
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
                sudo git -C /etc/nixos push -q
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
  };

  # Darwin desktop layer (room to grow; base is enough today).
  flake.modules.darwin.system-desktop = {
    imports = with inputs.self.modules.darwin; [
      system-default
    ];
  };

  # Home-manager desktop env shared by every user: the editor + CLI tools.
  flake.modules.homeManager.system-desktop = {
    imports = with inputs.self.modules.homeManager; [
      system-default
      nvf
      cli-tools
    ];
  };
}
