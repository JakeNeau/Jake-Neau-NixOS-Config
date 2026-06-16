{inputs, ...}: let
  # Two llama.cpp servers, one model each: an instruct model for the on-demand
  # "explain this symbol" hover, and a smaller FIM model for inline (llama.vim)
  # completion. nvf points <leader>ak at the hover port's chat endpoint and
  # llama.vim at the FIM port's /infill endpoint (see modules/programs/nvf).
  ports = {
    hover = 8011;
    fim = 8012;
  };

  # GGUFs pinned as fixed-output derivations: reproducible, stored in /nix/store,
  # no runtime "pull" (the whole reason this stack uses bare llama-server rather
  # than Ollama). Models are shared by both platforms, so build them from pkgs.
  mkArgs = pkgs: let
    hover = pkgs.fetchurl {
      name = "qwen2.5-coder-7b-instruct-q4_k_m.gguf";
      url = "https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf";
      hash = "sha256-FmT8yrc0Z0pQdjSQqMaTG3Dj8vjsEAMbVIBtMOX5VrY=";
    };
    fim = pkgs.fetchurl {
      name = "qwen2.5-coder-1.5b-q8_0.gguf";
      url = "https://huggingface.co/ggml-org/Qwen2.5-Coder-1.5B-Q8_0-GGUF/resolve/main/qwen2.5-coder-1.5b-q8_0.gguf";
      hash = "sha256-KYcclNFXJ6biQ/eaNxE9SuYlpiFbXoAL9Bojry2jKDI=";
    };
    bin = "${pkgs.llama-cpp}/bin/llama-server";
  in {
    # instruct/chat model for the hover summary (/v1/chat/completions)
    hover = [bin "-m" "${hover}" "--port" (toString ports.hover) "-c" "8192" "-ngl" "99"];
    # FIM model with llama.vim's recommended low-latency flags (/infill)
    fim = [bin "-m" "${fim}" "--port" (toString ports.fim) "--ctx-size" "0" "-ub" "1024" "-b" "1024" "--cache-reuse" "256" "-ngl" "99"];
  };
in {
  # macOS: launchd user agents. nixpkgs' llama-cpp builds with Metal on Darwin,
  # so -ngl offloads to the GPU automatically. Logs go to user-writable /tmp.
  flake.modules.darwin.llama-server = {pkgs, ...}: let
    args = mkArgs pkgs;
    agent = name: program: {
      serviceConfig = {
        ProgramArguments = program;
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/tmp/${name}.log";
        StandardErrorPath = "/tmp/${name}.log";
      };
    };
  in {
    launchd.user.agents.llama-hover = agent "llama-hover" args.hover;
    launchd.user.agents.llama-fim = agent "llama-fim" args.fim;
  };

  # NixOS: systemd user services. -ngl is a no-op on a CPU-only llama-cpp build,
  # so this is safe on hosts without a configured GPU backend.
  flake.modules.nixos.llama-server = {
    pkgs,
    lib,
    ...
  }: let
    args = mkArgs pkgs;
    service = description: program: {
      inherit description;
      wantedBy = ["default.target"];
      serviceConfig = {
        ExecStart = lib.escapeShellArgs program;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  in {
    systemd.user.services.llama-hover = service "llama-server: hover/chat model (port 8011)" args.hover;
    systemd.user.services.llama-fim = service "llama-server: FIM model (port 8012)" args.fim;
  };
}
