function l --description "Runs eza with a lot of information"
  set -l depth
  set -l paths

  for arg in $argv
    # The first bare number is the tree depth; everything else is a path
    if test -z "$depth" -a (string match -r '^[0-9]+$' "$arg" | count) -gt 0
      set depth "$arg"
    else
      set -a paths "$arg"
    end
  end

  if test -z "$depth"
    eza -algh --git-repos --git --icons --group-directories-first $paths
    return
  end

  # eza's -L already caps directories, so only files need the check. Files
  # from a recursive glob like **.sh are dropped once they sit deeper than
  # the depth.
  set -l kept
  for p in $paths
    if test -d "$p" || test (path normalize "$p" | string split / | count) -le $depth
      set -a kept "$p"
    end
  end

  # Every given path was too deep; show nothing rather than fall back to
  # listing the whole current directory
  if test (count $paths) -gt 0 -a (count $kept) -eq 0
    return
  end

  eza -algh --git-repos --git --icons --group-directories-first -T -L=$depth $kept
end
