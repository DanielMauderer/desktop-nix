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

  services = {
    # Always at home, so the share mounts direct over the LAN (SSH still rides the
    # tunnel). `enable` stays off until enrollment.
    homeServerClient = {
      enable = true;
      address = "10.100.0.2/32";
      nfsHost = "192.168.178.96"; # home-server's LAN IP
      # Always-home + same LAN as the server: tunnel straight to its LAN IP so the
      # handshake doesn't depend on Fritz!Box NAT hairpin. Roaming hosts keep the
      # default vpn.mauderer.work:51820 (WAN) endpoint.
      endpoint = "192.168.178.96:51820";
    };

    # Push metrics + warning-level journal to the server's Grafana. Rides the wg0
    # tunnel above, which is why it is enabled alongside it.
    homeServerTelemetry.enable = true;

    # Second tunnel (wg1) from the Fritz!Box wg.conf; key lives in
    # secrets/desktop/vpn.yaml.
    vpnClient = {
      enable = true;
      address = [ "192.168.178.208/24,fde5:32d8:78dc::208/64" ]; # Address =
      endpoint = "9m2lqds859vjlh5k.myfritz.net:52641"; # Endpoint =
      publicKey = "2vaNA56VJJW4MU4zMaQffBCt9Eac5p7lum80988/Nhc="; # PublicKey =
      presharedKey = true; # PresharedKey = → secrets/desktop/vpn.yaml, vpn-wg-psk
    };
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
