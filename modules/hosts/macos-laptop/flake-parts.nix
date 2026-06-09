{inputs, ...}: {
  flake.darwinConfigurations = inputs.self.lib.mkDarwin "aarch64-darwin" "macos-laptop";
}
