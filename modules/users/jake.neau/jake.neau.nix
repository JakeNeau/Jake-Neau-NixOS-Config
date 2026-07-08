{inputs, ...}: {
  # Jake's work user. Lives only on the macOS work laptop. Admin.
  # Kubernetes CLI tools on cedar only — per-user-per-host, so it rides the
  # user declaration, not the aspect (which would put it on every machine).
  flake.users."jake.neau".hosts.cedar.programs = ["kubernetes"];

  flake.modules = inputs.self.factory.user "jake.neau" true;
}
