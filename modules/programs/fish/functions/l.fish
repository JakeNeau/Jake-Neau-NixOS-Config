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

  if not test -z "$depth"
    eza -algh --git-repos --git --icons --group-directories-first -T -L=$depth $paths
  else
    eza -algh --git-repos --git --icons --group-directories-first $paths
  end
end
