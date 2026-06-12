function nr --description "Pulls, verifies every environment in the flake, commits and pushes, then rebuilds the system. Aborts if any step fails"
  argparse 'n/no-git' 'f/full-output' -- $argv
  or return 1

  # The flake location, configuration class, and rebuild command are the
  # only platform-specific parts; everything else is shared
  set -l flake /etc/nixos
  set -l this_class nixosConfigurations
  set -l rebuild nixos-rebuild switch --upgrade --flake
  if test (uname) = Darwin
    set flake /etc/nix-darwin
    set this_class darwinConfigurations
    set rebuild darwin-rebuild switch --flake
  end

  # Quiet by default; -f/--full-output shows everything
  set -l git_quiet -q
  set -l nix_quiet --quiet
  if set -q _flag_full_output
    set git_quiet
    set nix_quiet
  end

  suu git -C $flake pull $git_quiet
  or begin
    echo "nr: git pull failed, aborting" >&2
    return 1
  end

  sudo nix flake update --flake $flake $nix_quiet
  or begin
    echo "nr: nix flake update failed, aborting" >&2
    return 1
  end

  # Stage everything before verifying: nix ignores untracked files when it
  # evaluates a dirty git tree, so brand-new files would otherwise be
  # invisible to the verification (and to the rebuild) below
  if not set -q _flag_no_git
    sudo git -C $flake add -A
    or begin
      echo "nr: git add failed, aborting" >&2
      return 1
    end
  end

  # Verify that every environment defined by the flake still evaluates,
  # regardless of which machine it targets
  for class in nixosConfigurations darwinConfigurations homeConfigurations
    set -l target config.system.build.toplevel
    if test $class = homeConfigurations
      set target activationPackage
    end

    set -l hosts (nix eval "$flake#$class" --apply 'c: builtins.concatStringsSep "\n" (builtins.attrNames c)' --raw)
    or begin
      echo "nr: could not list the hosts in $class, aborting" >&2
      return 1
    end

    for host in $hosts
      echo "Verifying $class.$host..."
      nix eval "$flake#$class.$host.$target.drvPath" $nix_quiet >/dev/null
      or begin
        echo "nr: $class.$host failed to verify, aborting (nothing was committed or pushed)" >&2
        return 1
      end
    end
  end

  # Fully build this machine's configuration as the last verification step,
  # so nothing is committed or pushed unless the build is known to succeed
  set -l this_host (hostname -s)
  echo "Building $this_class.$this_host..."
  nix build "$flake#$this_class.$this_host.config.system.build.toplevel" --no-link $nix_quiet
  or begin
    echo "nr: the build for $this_host failed, aborting (nothing was committed or pushed)" >&2
    return 1
  end

  # The switch at the end creates the next generation; predict its number now
  # so the commit can be named after it
  set -l new_generation (math (readlink /nix/var/nix/profiles/system | cut -d- -f2) + 1)

  if not set -q _flag_no_git
    set -l new_commit_message
    if test (count $argv) -eq 0
      # Amend the last commit with the new generation if a message is not specified
      set -l last_commit_message (git -C $flake log -1 --pretty=%s)
      if test (string match -r '^([\w.-]+ )?Generation [0-9]+:' -- $last_commit_message | count) -gt 0
        set new_commit_message (string replace -r '^([\w.-]+ )?Generation [0-9]+:' "$this_host Generation $new_generation:" -- $last_commit_message)
      else
        set new_commit_message "$this_host Generation $new_generation: $last_commit_message"
      end
      sudo git -C $flake commit --amend $git_quiet -m "$new_commit_message"
      or begin
        echo "nr: amending the last commit failed, aborting before the push and rebuild" >&2
        return 1
      end
      suu git -C $flake push --force-with-lease $git_quiet
      or begin
        echo "nr: git push failed, aborting before the rebuild (the amended commit is still local)" >&2
        return 1
      end
    # Make a new commit if the message is specified
    else
      set new_commit_message "$this_host Generation $new_generation: $argv"
      sudo git -C $flake commit $git_quiet -m "$new_commit_message"
      or begin
        echo "nr: git commit failed, aborting before the push and rebuild" >&2
        return 1
      end
      suu git -C $flake push $git_quiet
      or begin
        echo "nr: git push failed, aborting before the rebuild (the commit is still local)" >&2
        return 1
      end
    end
    echo "Commit \"$new_commit_message\" pushed to GitHub"
  end

  # Everything is already built and verified, so the rebuild is mostly activation
  echo "Rebuilding the system configuration..."
  sudo $rebuild $flake $nix_quiet
  or begin
    echo "nr: the rebuild failed" >&2
    return 1
  end

  set -l actual_generation (readlink /nix/var/nix/profiles/system | cut -d- -f2)
  echo "System configuration rebuilt for generation $actual_generation"
  if not set -q _flag_no_git; and test "$actual_generation" != "$new_generation"
    echo "Warning: the commit was named $this_host Generation $new_generation but the system is at generation $actual_generation"
  end
end
