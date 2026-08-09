{...}: {
  flake.modules.darwin.ac-power = {
    system.activationScripts.ac-power.text = ''
      /usr/bin/pmset -c sleep 0
    '';
  };
}
