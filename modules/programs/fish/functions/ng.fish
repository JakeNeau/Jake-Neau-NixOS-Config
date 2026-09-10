function ng --description "Nix Garbage: deletes old generations of your profiles and root's, then collects the store. -o/--delete-older-than <period> keeps generations newer than <period>"
  argparse 'o/delete-older-than=' -- $argv
  or return 1
  if test (count $argv) -ne 0
    echo "ng: takes no positional arguments" >&2
    echo "Usage: ng [-o/--delete-older-than <period>]" >&2
    return 1
  end

  set -l prune --delete-old
  if set -q _flag_delete_older_than
    set prune --delete-older-than $_flag_delete_older_than
  end

  # Under sudo, nix-collect-garbage prunes only root's profiles, so the
  # user's own generations would keep rooting old packages (NixOS/nix#8508)
  nix-collect-garbage $prune
  or return

  # Without sudo rights the user pass is all that can run
  if not sudo -v
    echo "ng: no sudo access, skipped root's profiles and the system store" >&2
    return
  end
  sudo nix-collect-garbage $prune
end
