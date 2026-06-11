{
  inputs,
  lib,
  ...
}: {
  # Fastfetch: the system-info splash shown by the fish greeting on every
  # machine. The aspects are minted by the fastfetch factory
  # (modules/factory/fastfetch); each host imports the variant matching its
  # hardware — fastfetch-desktop, or fastfetch-laptop, which adds a boxed
  # Power section (power adapter + battery).
  flake.modules = lib.mkMerge [
    (inputs.self.factory.fastfetch false)
    (inputs.self.factory.fastfetch true)
  ];
}
