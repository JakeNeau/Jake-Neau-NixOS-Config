{
  # Cross-platform command-line programs, shared by NixOS desktops and macOS
  # hosts. Linux/Wayland-specific terminal utilities stay in role-desktop.
  flake.modules.generic.cli = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      bottom # A TUI system monitor
      eza # A better version of ls written in rust
      ffmpeg # Video codec
      fzf # System wide fuzzy finder
      grc # Generic text colorizer
      jdk # Java Development Kit
      tldr # Summarize man pages for commands
      unzip # CLI file unzipping
      wget # Download web files from the command line
      zellij # A modern terminal multiplexer
    ];
  };
}
