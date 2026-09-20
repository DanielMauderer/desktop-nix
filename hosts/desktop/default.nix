{
  config,
  lib,
  pkgs,
  ...
}:
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

  # The Vega HDMI codec drives both heads (pin 0x3 = Acer on DP-3, pin 0xb = the
  # Samsung QBQ90S on DP-1), but PipeWire's ALSA card profiles only ever activate
  # one HDMI pin at a time — picking the TV silently took the monitor's sink away.
  # The codec has an independent converter per pin, so both PCMs can run at once.
  # Keep the card profile (Acer, with ELD/route handling) and bolt the TV on as a
  # second static node, so both show up as separate selectable outputs.
  #
  # Caveat: a static node ignores ELD, so this sink exists and swallows audio even
  # when the TV is off. "10" is the PCM for pin 0xb — it changes if the TV moves to
  # another port (check `aplay -l`). `hw:HDMI` not `hw:0`: the card index moves.
  services.pipewire.extraConfig.pipewire."91-hdmi-split".context.objects = [
    {
      factory = "adapter";
      args = {
        "factory.name" = "api.alsa.pcm.sink";
        "node.name" = "alsa_output.hdmi-samsung-tv";
        "node.description" = "Samsung TV (HDMI)";
        "media.class" = "Audio/Sink";
        "api.alsa.path" = "hw:HDMI,10";
        "audio.channels" = 2;
        "audio.position" = [
          "FL"
          "FR"
        ];
      };
    }
  ];

  # Desktop head layout; mkBefore so these match ahead of the laptop-internal
  # fallback. kanshi needs a profile per *exact* set of connected outputs, hence
  # the separate desktop+tv one — without it nothing matched while the TV was
  # plugged in and Hyprland fell back to its auto left-to-right placement.
  home-manager.users.maudi.services.kanshi.settings = lib.mkBefore [
    {
      profile = {
        name = "desktop+tv";
        outputs = [
          {
            criteria = "DP-3"; # Acer XF272U, 27" 1440p
            mode = "2560x1440@144";
            position = "0,0";
          }
          {
            criteria = "DP-2"; # Acer G276HL, 27" 1080p
            mode = "1920x1080@60";
            position = "2560,0";
          }
          {
            criteria = "DP-1"; # Samsung QBQ90S, geometry comes from the mirror below
            status = "enable";
          }
        ];
        # kanshi cannot mirror, so the TV is pointed at DP-3 from Hyprland. 0.56 is
        # Lua-only and dropped `hyprctl keyword monitor` ("unknown request"), so
        # this goes through the Lua API. 2560x1440 is in the TV's mode list, which
        # makes the mirrored image 1:1 instead of letterboxed inside 4K.
        #
        # A script, not an inline exec line: kanshi re-escapes quotes and spaces
        # for sh(1), and hyprctl then mangles the resulting Lua table literal.
        # It only sets runtime state: a Hyprland config reload drops the mirror
        # until the next topology change re-fires this.
        exec = toString (
          pkgs.writeShellScript "kanshi-mirror-tv" ''
            exec ${config.programs.hyprland.package}/bin/hyprctl eval 'hl.monitor{output="DP-1",mode="2560x1440@60",position="auto",scale=1,mirror="DP-3"}'
          ''
        );
      };
    }
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
