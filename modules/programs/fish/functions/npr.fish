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
  or begin
    echo "npr: could not build '$package_name' from nixpkgs (see the nix error above)" >&2
    return 1
  end
  mv result package-build-result
  or begin
    echo "npr: nix build succeeded but the ./result symlink could not be moved" >&2
    return 1
  end
  cd package-build-result
  eval $command
  cd $start_directory
  rm -rf package-build-result
  or begin
    echo "npr: could not remove $start_directory/package-build-result, remove it manually" >&2
    return 1
  end
end
