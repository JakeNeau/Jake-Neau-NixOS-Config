{ inputs, ... }:
{
  # SteamVR: installed and launched through Steam. These aspects hold the
  # system and home fixes it needs on NixOS.
  flake-file.inputs.steamvr-kernel-patch = {
    url = "file+https://github.com/Frogging-Family/community-patches/raw/master/linux61-tkg/cap_sys_nice_begone.mypatch";
    flake = false;
  };

  flake.modules.nixos.steamvr = {
    # SteamVR's compositor needs high-priority amdgpu contexts without CAP_SYS_NICE.
    boot.kernelPatches = [
      {
        name = "amdgpu-ignore-ctx-privileges";
        patch = inputs.steamvr-kernel-patch;
      }
    ];
  };

  # SteamVR writes its URI handlers where the launcher lists them.
  # These copies keep the handlers and hide them from the launcher.
  flake.modules.homeManager.steamvr =
    { config, lib, ... }:
    let
      bin = "${config.home.homeDirectory}/.local/share/Steam/steamapps/common/SteamVR/bin";
      hiddenHandler = scheme: name: exec: {
        ".local/share/applications/valve-${scheme}.desktop".text = ''
          [Desktop Entry]
          Name=${name}
          Comment=URI handler for ${scheme}://
          Exec="${exec}" %U
          Terminal=false
          Type=Application
          NoDisplay=true
          MimeType=x-scheme-handler/${scheme};
        '';
      };
    in
    {
      home.file = lib.mkMerge [
        (hiddenHandler "steamvr" "SteamVR" "${bin}/linux64/vrurlhandler")
        (hiddenHandler "vrmonitor" "VRMonitor" "${bin}/vrmonitor.sh")
      ];
    };
}
