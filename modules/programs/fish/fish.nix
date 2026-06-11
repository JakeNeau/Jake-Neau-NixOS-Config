{
  # Fish: the default interactive shell on every machine.
  #
  # NixOS [N]: fish is each user's login shell (set by modules/factory/user);
  #            interactive bash also hands off to fish so a stray bash session
  #            lands in the same place.
  # macOS [D]: macOS owns the account's login shell (zsh), so instead of
  #            changing the account, interactive zsh execs into fish.
  # Both [nd]: aliases, functions, and plugins live in home-manager; the
  #            NixOS-management helpers (nf/nc/nh/ns, nr, mc-*, r/s) are
  #            Linux-only.
  #
  # Related: ctrl-v/alt-c keybind fixups come from modules/system/copy-paste-remaps.

  flake.modules.nixos.fish = {pkgs, ...}: {
    # Registers fish in /etc/shells (required for it to be a login shell) and
    # wires vendor completions/config for fish plugin packages.
    programs.fish.enable = true;

    # If bash ever starts interactively, hand off to fish. Keeps bash as the
    # safe default for scripts and non-interactive shells.
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
  };

  flake.modules.darwin.fish = {pkgs, ...}: {
    # Installs fish system-wide, registers it in /etc/shells, and sets up the
    # nix environment + vendor plugin loading for fish sessions.
    programs.fish.enable = true;

    # macOS owns the account's login shell (zsh), so rather than chsh-ing the
    # user, interactive zsh execs into fish. Mirrors the bash hand-off on
    # NixOS; running `zsh` from inside fish still gives a real zsh.
    programs.zsh.interactiveShellInit = ''
      if [[ "$(basename "$(/bin/ps -o comm= -p $PPID)")" != "fish" && -z "$ZSH_EXECUTION_STRING" ]]; then
        [[ -o login ]] && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

  flake.modules.homeManager.fish = {
    pkgs,
    lib,
    ...
  }:
    lib.mkMerge [
      {
        # Plugins are picked up from the user profile through fish's vendor
        # dirs (NIX_PROFILES) on both platforms.
        home.packages = with pkgs.fishPlugins; [
          colored-man-pages # More interesting man pages
          fish-bd # Go back directories with bd
          # fzf-fish is marked broken on darwin only because its test suite
          # cannot run there; the plugin is plain fish script and works fine,
          # so build it without tests.
          (
            if pkgs.stdenv.isDarwin
            then
              fzf-fish.overrideAttrs (old: {
                doCheck = false;
                meta = old.meta // {broken = false;};
              })
            else fzf-fish # Search for multiple things with fzf
          )
          grc # A generic colorizer
          pisces # Adds parentheses, quotes, etc. in pairs
          plugin-sudope # Add sudo to a command when you forgot
          puffer # Useful text expansions
          pure # Minimal and fast fish prompt
          sponge # Remove typos from terminal
          z # Jump to previous directories
        ];

        programs.fish = {
          enable = true;
          shellAliases = {
            # Git aliases
            ga = "git add";
            gc = "git commit -m";
            gp = "git push";

            # General Command Aliases
            ng = "sudo nix-collect-garbage --delete-old";
            ls = "eza --icons --group-directories-first";
            l = "eza-long"; # This is needed because the function 'eza-long' will not override the fish default 'l' function if named 'l'
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
          '';
        };
      }

      # NixOS management helpers: editing /etc/nixos, the nixos-rebuild flow,
      # systemd power shortcuts, and the minecraft server controls.
      (lib.mkIf pkgs.stdenv.isLinux {
        programs.fish = {
          shellAliases = {
            # NixOS Aliases
            nf = "suu git -C /etc/nixos pull 1>/dev/null; sudoedit /etc/nixos/flake.nix";
            nc = "suu git -C /etc/nixos pull 1>/dev/null; sudoedit /etc/nixos/configuration.nix";
            nh = "suu git -C /etc/nixos pull 1>/dev/null; $EDITOR /etc/nixos/users/$USER/home.nix";
            ns = "suu git -C /etc/nixos pull 1>/dev/null; sops /etc/nixos/secrets/secrets.yaml";

            # Power aliases
            r = "sudo systemctl reboot";
            s = "sudo systemctl poweroff";
          };
          shellInit = ''
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
      })
    ];
}
