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
