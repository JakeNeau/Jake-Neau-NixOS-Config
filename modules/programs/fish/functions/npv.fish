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
