{ pkgs, ... }:
{
  # Automount USB sticks / SD cards under /run/media/$USER (needs system udisks2).
  services.udiskie = {
    enable = true;
    # test_list_keys reads the builder's process keyring, so it fails depending
    # on the host kernel (CI: "bytes length not a multiple of item size"). Hydra
    # doesn't always have the build cached, so CI compiles it and hits this.
    package = pkgs.udiskie.overridePythonAttrs (old: {
      disabledTests = (old.disabledTests or [ ]) ++ [ "test_list_keys" ];
    });
    automount = true;
    notify = true;
    tray = "auto";
  };
}
