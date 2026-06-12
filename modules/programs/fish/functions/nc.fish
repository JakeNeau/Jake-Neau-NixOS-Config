function nc --description "Pulls the system flake and opens it in the editor as root"
  set -l flake /etc/nixos
  if test (uname) = Darwin
    set flake /etc/nix-darwin
  end

  suu git -C $flake pull 1>/dev/null

  # sudoedit only handles regular files, so to open the whole flake
  # directory run the editor itself as root, resolving $EDITOR in the
  # user's PATH before sudo replaces it
  sudo (command -s $EDITOR) $flake
end
