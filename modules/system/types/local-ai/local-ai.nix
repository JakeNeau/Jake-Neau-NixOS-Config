{inputs, ...}: let
  # A system type for hosts that run local AI: pull in the llama-server feature
  # and record the fact so home-manager features (nvf's <leader>ak hover and
  # llama.vim autocomplete) can branch on systemConstants.localAi. Importing this
  # type is how a host opts in; aspen simply omits it.
  local-ai = class: {
    imports = [inputs.self.modules.${class}.llama-server];
    systemConstants.localAi = true;
  };
in {
  flake.modules.nixos.local-ai = local-ai "nixos";
  flake.modules.darwin.local-ai = local-ai "darwin";
}
