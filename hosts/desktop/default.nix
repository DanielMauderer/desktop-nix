{ lib, ... }:
{
  imports = [
    ../../modules/nixos/base
    ../../modules/nixos/desktop
    ../../modules/nixos/gaming
    ../../modules/nixos/waydroid
    ../../modules/nixos/discord
    ../../modules/nixos/net
    ./hardware.nix
    ./hardware/hardware-configuration.nix
  ];

  networking.hostName = "desktop";
  system.stateVersion = "25.05";

  # Always at home, so the share mounts direct over the LAN (SSH still rides the
  # tunnel). `enable` stays off until enrollment.
  services.homeServerClient = {
    enable = true;
    address = "10.100.0.2/32";
    nfsHost = "192.168.178.96"; # home-server's LAN IP
    # Always-home + same LAN as the server: tunnel straight to its LAN IP so the
    # handshake doesn't depend on Fritz!Box NAT hairpin. Roaming hosts keep the
    # default vpn.mauderer.work:51820 (WAN) endpoint.
    endpoint = "192.168.178.96:51820";
  };

  # Second tunnel (wg1) from the provider wg.conf. Off until this host's key is
  # in secrets/desktop/vpn.yaml; fill the three fields from the .conf.
  services.vpnClient = {
    # enable = true;                     # ← flip on after the sops step
    address = [ "FILL-ME/32" ]; # Address =
    endpoint = "FILL-ME:51820"; # Endpoint =
    publicKey = "FILL-ME="; # PublicKey =
  };

  # Dual-head desktop; mkBefore so it matches ahead of the laptop-internal fallback.
  home-manager.users.maudi.services.kanshi.settings = lib.mkBefore [
    {
      profile = {
        name = "desktop";
        outputs = [
          {
            criteria = "DP-3";
            mode = "2560x1440@144";
            position = "0,0";
          }
          {
            criteria = "DP-2";
            mode = "1920x1080@60";
            position = "2560,0";
          }
        ];
      };
    }
  ];

  # Pin workspaces 1-5 to DP-3 and 6-10 to DP-2 (single-output laptops share the
  # module but never set this, so they're unaffected). Hyprland 0.56+ is Lua-only:
  # these render as hl.workspace_rule calls, not the old hyprlang strings.
  home-manager.users.maudi.wayland.windowManager.hyprland.settings.workspace_rule =
    let
      rule = n: output: {
        _args = [
          (
            {
              workspace = toString n;
              monitor = output;
            }
            # First workspace on each output is the one it defaults to.
            // lib.optionalAttrs (n == 1 || n == 6) { default = true; }
          )
        ];
      };
    in
    map (n: rule n "DP-3") [
      1
      2
      3
      4
      5
    ]
    ++ map (n: rule n "DP-2") [
      6
      7
      8
      9
      10
    ];
}
