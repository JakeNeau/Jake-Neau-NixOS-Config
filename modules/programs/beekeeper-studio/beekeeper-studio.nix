{
  # Beekeeper Studio: a cross-platform SQL client (MySQL, Postgres, SQLite, ...).
  flake.modules.homeManager.beekeeper-studio = {pkgs, ...}: {
    home.packages = [pkgs.beekeeper-studio];
  };
}
