function l --description "Runs eza with a lot of information"
  set -l depth
  set -l path

  for arg in $argv
    # Set depth if depth is not set and the argument is a number
    if test -z "$depth" -a (string match -r '^[0-9]+$' "$arg" | count) -gt 0
      set depth "$arg"
    else if test -z "$path"
      set path "$arg"
    else
      echo "l: unexpected extra argument '$arg' (usage: l [depth] [path])" >&2
      return 1
    end
  end

  if not test -z "$depth"
    eza -algh --git-repos --git --icons --group-directories-first -T -L=$depth $path
  else
    eza -algh --git-repos --git --icons --group-directories-first $path
  end
end
