{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Flip after the host age key is enrolled and `sops updatekeys` has run on
  # secrets/work-laptop/*.yaml (INSTALL.md §2) — until then this box can't
  # decrypt them, and secret activation would fail.
  enrolled = true;
in
{
  imports = [
    ../../modules/nixos/base
    ../../modules/nixos/desktop
    ../../modules/nixos/net
    ./hardware.nix
    ./hardware/hardware-configuration.nix
  ];

  networking.hostName = "work-laptop";
  system.stateVersion = "25.05";

  # home-server VPN client (wg0, split-tunnel 10.100.0.0/24): `ssh home-server` +
  # the NFS share. Roams, so nfsHost stays at the VPN IP (the default).
  services.homeServerClient = {
    enable = true;
    address = "10.100.0.5/32";
  };

  # Work VPN (wg1) and personal secrets. Everything company-specific lives
  # inside the sops files, not in this repo's plaintext:
  # - secrets/work-laptop/vpn.yaml  `vpn-wg-conf`: the full wg-quick config
  #   (key, address, peer, MTU, keepalive) from the old NetworkManager `wg0`.
  # - secrets/work-laptop/user.yaml `ssh-id-ed25519` (passphrase-protected) and
  #   `npmrc` (the whole ~/.npmrc, registry tokens included).
  sops = lib.mkIf enrolled {
    secrets = {
      vpn-wg-conf.sopsFile = ../../secrets/work-laptop/vpn.yaml;
      ssh-id-ed25519 = {
        sopsFile = ../../secrets/work-laptop/user.yaml;
        owner = "maudi";
        path = "/home/maudi/.ssh/id_ed25519";
      };
      npmrc = {
        sopsFile = ../../secrets/work-laptop/user.yaml;
        owner = "maudi";
        path = "/home/maudi/.npmrc";
      };
    };
  };
  # Full IPv4 tunnel, on demand: `systemctl start wg-quick-wg1`. wg0 stays
  # reserved for the home-server client.
  networking.wg-quick.interfaces.wg1 = lib.mkIf enrolled {
    configFile = config.sops.secrets.vpn-wg-conf.path;
    autostart = false;
  };
  # sops-nix would otherwise create ~/.ssh root-owned for the key symlink.
  systemd.tmpfiles.rules = lib.mkIf enrolled [ "d /home/maudi/.ssh 0700 maudi users -" ];

  home-manager.users.maudi = {
    # Teams, work-only: Electron wrapper around the web client (Microsoft's
    # native Linux client is discontinued).
    # glab: GitLab CLI for the work GitLab.
    # git-spice: stacked MRs (split-branch skill). nixpkgs ships it only as `gs`,
    # which collides with Ghostscript, so add an unambiguous `git-spice` name.
    home.packages = [
      pkgs.teams-for-linux
      pkgs.glab
      (pkgs.symlinkJoin {
        name = "git-spice";
        paths = [ pkgs.git-spice ];
        postBuild = "ln -s gs $out/bin/git-spice";
      })
    ];

    # Personal GitLab-workflow Claude skills, usable in any work repo. Linked
    # per skill so ~/.claude/skills (claude.ai-synced skills) stays writable.
    home.file = lib.genAttrs' [ "fix-pipeline" "fix-mr-comments" "split-branch" ] (
      name:
      lib.nameValuePair ".claude/skills/${name}/SKILL.md" {
        source = ./claude-skills/${name}/SKILL.md;
      }
    );

    # Every commit on this machine, personal repos included, uses the work address.
    local.git.email = "daniel.mauderer@medicalvalues.de";

    # Keep the 5-min lock but lengthen Noctalia's auto-suspend to 30 min here.
    local.idleSuspendSeconds = 1800;

    # Docked: pin workspaces 1-5 to the left external and 6-10 to the right.
    # Static workspace rules (as on the desktop host) can't work here: the dock
    # renumbers DP-n on every replug and both M27Qs share one EDID serial. So the
    # rules are (re)written at runtime from the left-to-right order kanshi
    # arranged, on every layout change. hl.workspace_rule replaces a rule with
    # the same workspace selector, so re-running is idempotent. Fewer than two
    # externals: rules are left alone, and Hyprland puts workspaces on the
    # remaining outputs.
    wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
      -- Dual-external workspace pinning (hosts/work-laptop/default.nix)
      local function pin_docked_workspaces()
        local ext = {}
        for _, m in ipairs(hl.get_monitors()) do
          if m.enabled and not m.name:match("^eDP") then ext[#ext + 1] = m end
        end
        if #ext < 2 then return end
        table.sort(ext, function(a, b) return a.x < b.x end)
        for n = 1, 10 do
          local mon = (n <= 5 and ext[1] or ext[2]).name
          hl.workspace_rule({ workspace = tostring(n), monitor = mon, default = (n == 1 or n == 6) })
          local ws = hl.get_workspace(n)
          if ws and ws.monitor and ws.monitor.name ~= mon then
            hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(n), monitor = mon }))
          end
        end
      end
      hl.on("monitor.layout_changed", pin_docked_workspaces)
      pin_docked_workspaces()
    '';

    # Docked-at-desk (dual external) or docked-at-home (internal + HDMI); mkBefore
    # so a docked profile matches before the generic laptop-internal fallback.
    services.kanshi.settings = lib.mkBefore [
      {
        profile = {
          name = "work-laptop-docked-dual";
          outputs = [
            {
              criteria = "eDP-1";
              status = "disable";
            }
            # Match by EDID, not connector: the dock renumbers DP-n on replug.
            # Both M27Qs report the same bogus serial, so left/right follows
            # kanshi's head order (first entry takes the first matching head);
            # the positions below were picked to match the physical desk layout.
            # The globs must differ: kanshi rejects the whole config on a
            # duplicate criteria string within a profile.
            {
              criteria = "GIGA-BYTE TECHNOLOGY CO., LTD. M27Q *";
              position = "2560,0";
            }
            {
              criteria = "GIGA-BYTE TECHNOLOGY CO., LTD. M27Q 0x*";
              position = "0,0";
            }
          ];
        };
      }
      {
        profile = {
          name = "work-laptop-docked-hdmi";
          outputs = [
            {
              criteria = "eDP-1";
              position = "0,0";
            }
            {
              criteria = "HDMI-A-1";
              position = "1920,0";
            }
          ];
        };
      }
    ];
  };
}
