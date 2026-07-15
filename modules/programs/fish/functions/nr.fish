function nr --description "Pulls, verifies every environment in the flake, commits and pushes, then rebuilds the system and your home. Aborts if any step fails"
  argparse 'n/no-git' 's/staged' 'f/full-output' 'l/long=' -- $argv
  or return 1

  if set -q _flag_staged; and set -q _flag_no_git
    echo "nr: --staged and --no-git contradict each other" >&2
    return 1
  end

  # A body-only invocation would take the amend path, which has no place
  # for a fresh body without a fresh subject
  if set -q _flag_long; and test (count $argv) -eq 0
    echo "nr: --long needs a short <message> too" >&2
    return 1
  end

  if set -q _flag_long; and set -q _flag_no_git
    echo "nr: --long is pointless with --no-git (no commit is made)" >&2
    return 1
  end

  # The flake location, configuration class, and rebuild command are the
  # only platform-specific parts; everything else is shared
  #
  # darwin-rebuild has no --quiet, so the rebuild step gets its own quiet flag
  # (empty on macOS) while the nix subcommands below keep using --quiet
  set -l flake /etc/nixos
  set -l this_class nixosConfigurations
  set -l rebuild nixos-rebuild switch --upgrade --flake
  set -l rebuild_quiet --quiet
  if test (uname) = Darwin
    set flake /etc/nix-darwin
    set this_class darwinConfigurations
    set rebuild darwin-rebuild switch --flake
    set rebuild_quiet
  end

  # A leftover --staged stash holds changes every later run would silently
  # exclude; refuse to do anything until it is restored
  if string match -q "*nr --staged*" -- (git -C $flake stash list)
    echo "nr: unrestored changes from a previous 'nr --staged' run are stashed; run 'git -C $flake stash pop' to restore them first" >&2
    return 1
  end

  # Quiet by default; -f/--full-output shows everything
  set -l git_quiet -q
  set -l nix_quiet --quiet
  if set -q _flag_full_output
    set git_quiet
    set nix_quiet
    set rebuild_quiet
  end

  set -l stash_hint # empty until stashed; every abort message appends it
  # With --staged, park unstaged tracked changes: nix evaluates the working
  # tree, so it must equal the index for the run to see only staged content.
  # Skip when nothing is unstaged — popping a --keep-index stash whose
  # staged half got committed would re-apply it
  if set -q _flag_staged; and not sudo git -C $flake diff --quiet
    # the message lets the startup guard above recognize a leftover stash
    sudo git -C $flake stash push --keep-index -m "nr --staged" $git_quiet
    or begin
      echo "nr: git stash failed, aborting" >&2
      return 1
    end
    set stash_hint "; your unstaged changes are stashed; run 'git -C $flake stash pop' to restore them"
  end

  suu git -C $flake pull $git_quiet
  or begin
    echo "nr: git pull failed, aborting$stash_hint" >&2
    return 1
  end

  sudo nix flake update --flake $flake $nix_quiet
  or begin
    echo "nr: nix flake update failed, aborting$stash_hint" >&2
    return 1
  end

  # Stage everything before verifying: nix ignores untracked files when it
  # evaluates a dirty git tree, so brand-new files would otherwise be
  # invisible to the verification (and to the rebuild) below
  if not set -q _flag_no_git
    if set -q _flag_staged
      # only the flake.lock bump joins the commit; the stash above already
      # made the working tree equal the index
      sudo git -C $flake add flake.lock
    else
      sudo git -C $flake add -A
    end
    or begin
      echo "nr: git add failed, aborting$stash_hint" >&2
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
      echo "nr: could not list the hosts in $class, aborting$stash_hint" >&2
      return 1
    end

    for host in $hosts
      echo "Verifying $class.$host..."
      # The name must be quoted inside the fragment: nix splits it on '.',
      # so an unquoted home name like jake.neau@cedar breaks the attr path
      nix eval "$flake#$class.\"$host\".$target.drvPath" $nix_quiet >/dev/null
      or begin
        echo "nr: $class.$host failed to verify, aborting (nothing was committed or pushed)$stash_hint" >&2
        return 1
      end
    end
  end

  # Fully build this machine's configuration as the last verification step,
  # so nothing is committed or pushed unless the build is known to succeed
  set -l this_host (hostname -s)
  echo "Building $this_class.$this_host..."
  nix build "$flake#$this_class.\"$this_host\".config.system.build.toplevel" --no-link $nix_quiet
  or begin
    echo "nr: the build for $this_host failed, aborting (nothing was committed or pushed)$stash_hint" >&2
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
      # --amend -m replaces the whole message, so carry the old body forward
      set -l body_args
      # string collect keeps a multi-paragraph body as one element
      set -l last_body (git -C $flake log -1 --pretty=%b | string collect)
      if test -n "$last_body"
        set body_args -m "$last_body"
      end
      sudo git -C $flake commit --amend $git_quiet -m "$new_commit_message" $body_args
      or begin
        echo "nr: amending the last commit failed, aborting before the push and rebuild$stash_hint" >&2
        return 1
      end
      suu git -C $flake push --force-with-lease $git_quiet
      or begin
        echo "nr: git push failed, aborting before the rebuild (the amended commit is still local)$stash_hint" >&2
        return 1
      end
    # Make a new commit if the message is specified
    else
      set new_commit_message "$this_host Generation $new_generation: $argv"
      # -l/--long supplies an extended description as a second -m paragraph
      set -l body_args
      if set -q _flag_long
        set body_args -m "$_flag_long"
      end
      sudo git -C $flake commit $git_quiet -m "$new_commit_message" $body_args
      or begin
        echo "nr: git commit failed, aborting before the push and rebuild$stash_hint" >&2
        return 1
      end
      suu git -C $flake push $git_quiet
      or begin
        echo "nr: git push failed, aborting before the rebuild (the commit is still local)$stash_hint" >&2
        return 1
      end
    end
    echo "Commit \"$new_commit_message\" pushed to GitHub"
  end

  # Everything is already built and verified, so the rebuild is mostly activation
  echo "Rebuilding the system configuration..."
  sudo $rebuild $flake $rebuild_quiet
  or begin
    echo "nr: the rebuild failed$stash_hint" >&2
    return 1
  end

  set -l actual_generation (readlink /nix/var/nix/profiles/system | cut -d- -f2)
  echo "System configuration rebuilt for generation $actual_generation"
  if not set -q _flag_no_git; and test "$actual_generation" != "$new_generation"
    echo "Warning: the commit was named $this_host Generation $new_generation but the system is at generation $actual_generation"
  end

  # Reactivate only the invoking user's home (before any stash pop, so it
  # sees the verified tree); other users run hr themselves
  echo "Rebuilding your home configuration..."
  hr
  or begin
    echo "nr: the home rebuild failed$stash_hint" >&2
    return 1
  end

  # The staged half is already in the commit, so popping the parked changes
  # normally merges cleanly; on conflict git keeps the stash
  if test -n "$stash_hint"
    sudo git -C $flake stash pop $git_quiet
    or begin
      echo "nr: restoring your unstaged changes conflicted; they are still stashed, resolve and pop manually" >&2
      return 1
    end
  end
end
