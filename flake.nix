{
  description = "NixOS configuration for all machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Theming: derives a base16 palette from a wallpaper image at build time.
    stylix = {
      url = "git+https://github.com/nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia: native Wayland desktop shell (bar, launcher, notifications, OSD,
    # lock screen, wallpaper, session menu). Replaces the waybar/rofi/swaync/
    # swaylock/swayidle/swaybg/wlogout stack. Its home module auto-provides the
    # package. Needs nixpkgs-unstable, which this flake already tracks.
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia's community plugin repo, pinned here instead of letting Noctalia
    # clone + auto-update it at runtime: plugin code then lands through the same
    # reviewed flake.lock bump as everything else. Not a flake.
    noctalia-community-plugins = {
      url = "github:noctalia-dev/community-plugins";
      flake = false;
    };

    # twilight channel for reproducibility (release artifacts may be deleted).
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    sops-nix = {
      url = "git+https://github.com/Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "git+https://github.com/nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # gitleaks secret scanning: installed into .git/hooks on `nix develop` and
    # run as a flake check.
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The three below aren't packaged in nixpkgs; built with buildVimPlugin.
    ember-theme = {
      url = "github:ember-theme/nvim/7365b8dede43a82ed1df741275b75333422e5402";
      flake = false;
    };

    pretty-hover = {
      url = "github:Fildo7525/pretty_hover/934df974ef6158b100fe910e8556e6c4a66614c2";
      flake = false;
    };

    tiny-code-action = {
      url = "github:rachartier/tiny-code-action.nvim/0d040ed81f7953118b81cd12681fcdfcac069803";
      flake = false;
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      chaotic,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (nixpkgs) lib;

      preCommitCheck = inputs.git-hooks.lib.${system}.run {
        src = ./.;
        # git-hooks.nix dropped its built-in gitleaks hook, so define a custom
        # one. `gitleaks dir` scans the filesystem (no .git, which the flake-check
        # sandbox lacks); pass_filenames = false runs it once over the whole tree.
        hooks.gitleaks = {
          enable = true;
          name = "gitleaks";
          package = pkgs.gitleaks;
          entry = "${pkgs.gitleaks}/bin/gitleaks dir --no-banner --redact .";
          pass_filenames = false;
        };
      };
      mkHost = import ./lib/mkHost.nix {
        inherit
          inputs
          nixpkgs
          home-manager
          chaotic
          ;
      };

      # disk.nix is added only to the real config, never to the nixosTest nodes
      # (which import default.nix alone), so VMs use their own scratch disk.
      hosts = {
        private-laptop = mkHost {
          modules = [
            ./hosts/private-laptop/default.nix
            ./hosts/private-laptop/disk.nix
          ];
        };
        work-laptop = mkHost {
          modules = [
            ./hosts/work-laptop/default.nix
            ./hosts/work-laptop/disk.nix
          ];
        };
        desktop = mkHost {
          modules = [
            ./hosts/desktop/default.nix
            ./hosts/desktop/disk.nix
          ];
          withChaotic = true;
        };
        home-server = mkHost {
          modules = [
            ./hosts/home-server/default.nix
            ./hosts/home-server/disk.nix
          ];
        };
      };

      # Eval-time host assertions: a failure aborts `nix flake check` naming
      # every failed assertion; extraScript runs at build time on rendered files.
      mkHostCheck =
        name: assertions: extraScript:
        let
          failed = builtins.filter (a: !a.assertion) assertions;
        in
        if failed != [ ] then
          throw "host-assertions-${name} failed:\n${lib.concatMapStringsSep "\n" (a: "  - ${a.name}") failed}"
        else
          pkgs.runCommand "host-assertions-${name}" { } ''
            ${extraScript}
            touch $out
          '';

      kanshiConfig =
        host: hosts.${host}.config.home-manager.users.maudi.xdg.configFile."kanshi/config".source;

      # Hyprland 0.56+ is Lua-only, so the rendered config is a program, not a
      # key/value file: a bad `hl.*` call or a module still emitting hyprlang
      # syntax produces a file that builds fine and only fails at login. Parse it
      # in CI. This catches syntax, not API misuse — a nested Hyprland with
      # HYPRLAND_CONFIG set and `hyprctl configerrors` is the check for that, and
      # it needs a compositor, so it stays a manual pre-rebuild step.
      hyprlandLuaCheck =
        host:
        let
          luaConfig = hosts.${host}.config.home-manager.users.maudi.xdg.configFile."hypr/hyprland.lua".source;
        in
        ''
          ${pkgs.luajit}/bin/luajit -bl ${luaConfig} /dev/null
          # Guard against a module reverting to hyprlang block syntax, which is
          # valid-looking config that Hyprland will never read.
          ! grep -qE '^\s*(windowrule|layerrule|workspace|bind[emd]?)\s*[={]' ${luaConfig}
        '';

      kanshiProfileNames =
        cfg: map (p: p.profile.name) cfg.home-manager.users.maudi.services.kanshi.settings;

      # Shared by every host; baseAssertions / serverAssertions extend it.
      commonAssertions = host: cfg: [
        {
          name = "hostName is ${host}";
          assertion = cfg.networking.hostName == host;
        }
        {
          name = "user maudi exists with fish shell";
          assertion = (cfg.users.users ? maudi) && (cfg.users.users.maudi.shell.pname or null) == "fish";
        }
        {
          name = "stateVersion is 25.05";
          assertion = cfg.system.stateVersion == "25.05";
        }
        {
          name = "home-manager manages maudi";
          assertion = cfg.home-manager.users ? maudi;
        }
        {
          name = "fish managed in home";
          assertion = cfg.home-manager.users.maudi.programs.fish.enable;
        }
        {
          name = "starship prompt enabled";
          assertion = cfg.home-manager.users.maudi.programs.starship.enable;
        }
        {
          name = "podman enabled with docker compat";
          assertion = cfg.virtualisation.podman.enable && cfg.virtualisation.podman.dockerCompat;
        }
        {
          name = "sops age key derived from host ssh ed25519 key";
          assertion = builtins.elem "/etc/ssh/ssh_host_ed25519_key" cfg.sops.age.sshKeyPaths;
        }
        {
          name = "root account locked";
          assertion = cfg.users.users.root.hashedPassword == "!";
        }
        {
          name = "firewall enabled";
          assertion = cfg.networking.firewall.enable;
        }
        {
          name = "auditd enabled for security-event logging";
          assertion = cfg.security.auditd.enable && cfg.security.audit.enable;
        }
        {
          name = "security updates applied daily";
          assertion = cfg.system.autoUpgrade.enable && cfg.system.autoUpgrade.dates == "daily";
        }
        {
          name = "tracks the CI-gated release branch";
          assertion = lib.hasSuffix "/release" cfg.system.autoUpgrade.flake;
        }
      ];

      # For the desktop/workstation hosts (those that import modules/nixos/base).
      baseAssertions =
        host: cfg:
        commonAssertions host cfg
        ++ [
          {
            name = "stylix enabled with a wallpaper";
            assertion = cfg.stylix.enable && cfg.stylix.image != null;
          }
          {
            name = "direnv + nix-direnv enabled in home";
            assertion =
              cfg.home-manager.users.maudi.programs.direnv.enable
              && cfg.home-manager.users.maudi.programs.direnv.nix-direnv.enable;
          }
          {
            name = "libvirtd enabled with swtpm TPM emulation";
            assertion = cfg.virtualisation.libvirtd.enable && cfg.virtualisation.libvirtd.qemu.swtpm.enable;
          }
          {
            name = "virt-manager enabled and maudi in libvirtd group";
            assertion =
              cfg.programs.virt-manager.enable && builtins.elem "libvirtd" cfg.users.users.maudi.extraGroups;
          }
          {
            name = "allowUnfreePredicate whitelists spotify";
            assertion = cfg.nixpkgs.config.allowUnfreePredicate pkgs.spotify;
          }
          {
            name = "spotify in maudi home.packages";
            assertion = builtins.any (
              p: (p.pname or "") == "spotify"
            ) cfg.home-manager.users.maudi.home.packages;
          }
          {
            name = "SSH daemon disabled";
            assertion = !cfg.services.openssh.enable;
          }
        ];

      # For the headless home-server (core + server, not base). SSH is enabled
      # here — the one host that allows remote login — but only across the VPN.
      serverAssertions =
        host: cfg:
        commonAssertions host cfg
        ++ [
          {
            name = "SSH daemon enabled";
            assertion = cfg.services.openssh.enable;
          }
          {
            name = "SSH is key-only, no root login";
            assertion =
              (cfg.services.openssh.settings.PasswordAuthentication == false)
              && (cfg.services.openssh.settings.PermitRootLogin == "no");
          }
          {
            name = "SSH (:22) admitted only on the wg0 VPN interface, never the WAN";
            assertion =
              builtins.elem 22 cfg.networking.firewall.interfaces.wg0.allowedTCPPorts
              && !(builtins.elem 22 cfg.networking.firewall.allowedTCPPorts);
          }
          {
            name = "WireGuard server wg0 listens on UDP 51820";
            assertion =
              (cfg.networking.wireguard.interfaces ? wg0)
              && cfg.networking.wireguard.interfaces.wg0.listenPort == 51820;
          }
          {
            name = "WireGuard UDP port open on the WAN";
            assertion = builtins.elem 51820 cfg.networking.firewall.allowedUDPPorts;
          }
          {
            name = "reverse-proxy HTTP/HTTPS (80/443) open on the WAN";
            assertion =
              builtins.elem 80 cfg.networking.firewall.allowedTCPPorts
              && builtins.elem 443 cfg.networking.firewall.allowedTCPPorts;
          }
          {
            name = "reverse-proxy runs the Nginx Proxy Manager container";
            assertion = cfg.virtualisation.oci-containers.containers ? npm;
          }
          {
            name = "NPM admin UI (81) never exposed on the WAN";
            assertion = !(builtins.elem 81 cfg.networking.firewall.allowedTCPPorts);
          }
          {
            name = "NPM admin port published on the VPN address only, never all interfaces";
            assertion =
              let
                ports = cfg.virtualisation.oci-containers.containers.npm.ports or [ ];
              in
              builtins.elem "10.100.0.1:81:81" ports && !(builtins.elem "81:81" ports);
          }
          {
            name = "NPM publishes the public 80/443 proxy ports";
            assertion =
              let
                ports = cfg.virtualisation.oci-containers.containers.npm.ports or [ ];
              in
              builtins.elem "80:80" ports && builtins.elem "443:443" ports;
          }
          {
            # The Actions runner deliberately holds this socket, but it does so
            # as a host systemd service (DOCKER_HOST + the podman group), never
            # as a container with the socket bind-mounted in. This guard stays
            # exact: no container, runner-related or not, gets the socket.
            name = "no service container mounts the management socket (escape guard)";
            assertion =
              let
                mounts = lib.concatMap (c: c.volumes) (lib.attrValues cfg.virtualisation.oci-containers.containers);
              in
              !(lib.any (v: lib.hasInfix "docker.sock" v || lib.hasInfix "podman.sock" v) mounts);
          }
          {
            name = "NPM container runs with no-new-privileges hardening";
            assertion = builtins.elem "--security-opt=no-new-privileges" (
              cfg.virtualisation.oci-containers.containers.npm.extraOptions or [ ]
            );
          }
          {
            name = "ZFS filesystem support enabled";
            assertion = cfg.boot.supportedFilesystems.zfs or false;
          }
          {
            name = "unique hostId set (required by ZFS)";
            assertion = cfg.networking.hostId != null && cfg.networking.hostId != "";
          }
          {
            name = "NFS server enabled for the file share";
            assertion = cfg.services.nfs.server.enable;
          }
          {
            name = "podman docker-compatible socket enabled for service hosting";
            assertion = cfg.virtualisation.podman.dockerSocket.enable;
          }
          {
            name = "oci-containers backend is podman";
            assertion = cfg.virtualisation.oci-containers.backend == "podman";
          }
          {
            name = "Forgejo enabled on the SQLite backend";
            assertion = cfg.services.forgejo.enable && cfg.services.forgejo.database.type == "sqlite3";
          }
          {
            name = "Forgejo public URL is HTTPS (TLS terminates at the reverse proxy)";
            assertion = lib.hasPrefix "https://" cfg.services.forgejo.settings.server.ROOT_URL;
          }
          {
            name = "Forgejo self-registration disabled (single-user forge)";
            assertion = cfg.services.forgejo.settings.service.DISABLE_REGISTRATION;
          }
          {
            name = "Forgejo Actions and push mirroring enabled";
            assertion =
              cfg.services.forgejo.settings.actions.ENABLED && cfg.services.forgejo.settings.mirror.ENABLED;
          }
          {
            name = "Forgejo dumps land on the redundant ZFS pool";
            assertion =
              cfg.services.forgejo.dump.enable
              && lib.hasPrefix "/hdd_pool_1/" cfg.services.forgejo.dump.backupDir;
          }
          {
            # The real guard on the whole design: Forgejo's :4000 and :2222 are
            # admitted by source-restricted nftables rules, so neither may ever
            # appear in the globally-open set. Stated as an exact match rather
            # than two absence checks, so any future port has to be argued for.
            name = "WAN TCP surface is exactly 80/443";
            assertion =
              lib.unique (builtins.sort (a: b: a < b) cfg.networking.firewall.allowedTCPPorts) == [
                80
                443
              ];
          }
          {
            # extraInputRules is an nftables-only option: under the iptables
            # backend these rules are silently dropped, so checking their text
            # without checking the backend would assert nothing.
            name = "Forgejo HTTP and git-SSH admitted only from named source ranges (nftables backend)";
            assertion =
              let
                rules = cfg.networking.firewall.extraInputRules;
              in
              cfg.networking.nftables.enable
              && lib.hasInfix "ip saddr { 10.88.0.0/16, 10.100.0.0/24 } tcp dport 4000 accept" rules
              && lib.hasInfix "tcp dport 2222 accept" rules;
          }
          {
            # Vacuously true while the runner is opt-in, but it pins the shape:
            # if it is ever enabled it must be the native unit, which reaches
            # podman via DOCKER_HOST rather than a mounted socket.
            name = "Actions runner (when enabled) runs as a host service";
            assertion = cfg.services.forgejoRunner.enable -> (cfg.systemd.services ? gitea-runner-forgejo);
          }
          {
            name = "Paperless enabled on the SQLite backend";
            assertion = cfg.services.paperless.enable && !cfg.services.paperless.database.createLocally;
          }
          {
            # The whole point of the archive's exposure design: it is admitted on
            # the VPN interface only. The "WAN TCP surface is exactly 80/443"
            # assertion above is the other half — it keeps :28981 out of the
            # globally-open set.
            name = "Paperless admitted only on the wg0 VPN interface, never the WAN";
            assertion =
              let
                inherit (cfg.services.paperless) port;
              in
              builtins.elem port cfg.networking.firewall.interfaces.wg0.allowedTCPPorts
              && !(builtins.elem port cfg.networking.firewall.allowedTCPPorts);
          }
          {
            # Unlike Forgejo there is no public hostname for the archive: no
            # nginx vhost, no NPM proxy host, nothing for TLS to terminate on.
            # Adding one would silently undo the VPN-only property.
            name = "Paperless is not published through a reverse proxy";
            assertion = !cfg.services.paperless.configureNginx && cfg.services.paperless.domain == null;
          }
          {
            # The user's stated constraint: the 3000 range is already taken.
            name = "Paperless avoids the reserved 3000-3010 port range";
            assertion =
              let
                inherit (cfg.services.paperless) port;
              in
              port < 3000 || port > 3010;
          }
          {
            name = "Paperless state, media and exports live on the redundant ZFS pool";
            assertion =
              let
                p = cfg.services.paperless;
              in
              lib.hasPrefix "/hdd_pool_1/" p.dataDir
              && lib.hasPrefix "/hdd_pool_1/" p.mediaDir
              && p.exporter.enable
              && lib.hasPrefix "/hdd_pool_1/" p.exporter.directory;
          }
          {
            # The drop folder has to sit inside the NFS export from nfs.nix, or
            # clients have no way to put documents in.
            name = "Paperless consumption dir is inside the NFS-exported share";
            assertion = lib.hasPrefix "/hdd_pool_1/share/" cfg.services.paperless.consumptionDir;
          }
          {
            # Guards the ordering fix: without this oneshot the paperless units
            # race zfs-mount.service and fail 226/NAMESPACE on a missing dir.
            name = "Paperless directories are created after the ZFS pool is mounted";
            assertion =
              let
                unit = cfg.systemd.services.paperless-data-dirs or null;
              in
              unit != null && builtins.elem "zfs-mount.service" unit.after;
          }

          # --- Observability: metrics.nix + logs.nix + grafana.nix ---
          {
            # Loopback-bound and never firewalled open: the expression browser
            # is an unauthenticated read of every metric on the box, and Grafana
            # (the only intended reader) runs on this same host.
            name = "Prometheus is loopback-only with bounded retention";
            assertion =
              let
                p = cfg.services.prometheus;
              in
              p.enable
              && p.listenAddress == "127.0.0.1"
              && p.retentionTime != ""
              && !(builtins.elem p.port cfg.networking.firewall.allowedTCPPorts)
              && lib.any (lib.hasPrefix "--storage.tsdb.retention.size=") p.extraFlags;
          }
          {
            name = "node and smartctl exporters enabled, both loopback-only";
            assertion =
              let
                e = cfg.services.prometheus.exporters;
              in
              e.node.enable
              && e.node.listenAddress == "127.0.0.1"
              && e.smartctl.enable
              && e.smartctl.listenAddress == "127.0.0.1";
          }
          {
            # Off by default, and the reason a failed unit is visible on a
            # dashboard instead of only in the journal.
            name = "node exporter reports systemd unit state";
            assertion = builtins.elem "systemd" cfg.services.prometheus.exporters.node.enabledCollectors;
          }
          {
            name = "Loki log store lives on the redundant ZFS pool";
            assertion =
              let
                c = cfg.services.loki.configuration;
              in
              cfg.services.loki.enable
              && lib.hasPrefix "/hdd_pool_1/" c.common.path_prefix
              && lib.hasPrefix "/hdd_pool_1/" c.common.storage.filesystem.chunks_directory
              && lib.hasPrefix "/hdd_pool_1/" c.storage_config.tsdb_shipper.active_index_directory
              && lib.hasPrefix "/hdd_pool_1/" c.compactor.working_directory;
          }
          {
            # Logs grow without bound by nature; the compactor is what deletes
            # them. Without retention the pool fills instead.
            name = "Loki enforces retention";
            assertion =
              let
                c = cfg.services.loki.configuration;
              in
              c.compactor.retention_enabled && c.limits_config.retention_period != null;
          }
          {
            # :3100 is push AND query with no authentication (`auth_enabled =
            # false` only switches off the tenant header), so the source
            # restriction *is* the access control. Stated as an exact rule text
            # so widening it has to be argued for, like the Forgejo rules above.
            name = "Loki :3100 admitted only from the podman bridge, LAN and VPN";
            assertion =
              let
                port = cfg.services.loki.configuration.server.http_listen_port;
                rule = "ip saddr { 10.88.0.0/16, 192.168.178.0/24, 10.100.0.0/24 } tcp dport ${toString port} accept";
              in
              cfg.networking.nftables.enable
              && !(builtins.elem port cfg.networking.firewall.allowedTCPPorts)
              && lib.hasInfix rule cfg.networking.firewall.extraInputRules;
          }
          {
            name = "the journal is shipped into Loki by Alloy";
            assertion =
              let
                etc = cfg.environment.etc;
              in
              cfg.services.alloy.enable
              && (etc ? "alloy/config.alloy")
              && lib.hasInfix "loki.source.journal" etc."alloy/config.alloy".text;
          }
          {
            # Alloy runs under DynamicUser, so without this group the journal
            # source starts and reads nothing but Alloy's own messages.
            name = "Alloy is in the systemd-journal group";
            assertion = builtins.elem "systemd-journal" (
              cfg.systemd.services.alloy.serviceConfig.SupplementaryGroups or [ ]
            );
          }
          {
            name = "Grafana state lives on the redundant ZFS pool";
            assertion =
              cfg.services.grafana.enable && lib.hasPrefix "/hdd_pool_1/" cfg.services.grafana.dataDir;
          }
          {
            # The whole point of Grafana's exposure design, and the same shape
            # as the Paperless assertion above: admitted on the VPN interface
            # only, with "WAN TCP surface is exactly 80/443" as the other half.
            name = "Grafana admitted only on the wg0 VPN interface, never the WAN";
            assertion =
              let
                inherit (cfg.services.grafana.settings.server) http_port;
              in
              builtins.elem http_port cfg.networking.firewall.interfaces.wg0.allowedTCPPorts
              && !(builtins.elem http_port cfg.networking.firewall.allowedTCPPorts);
          }
          {
            # The user's stated constraint, same as for Paperless: the 3000
            # range is already taken — which is Grafana's own default port.
            name = "Grafana avoids the reserved 3000-3010 port range";
            assertion =
              let
                inherit (cfg.services.grafana.settings.server) http_port;
              in
              http_port < 3000 || http_port > 3010;
          }
          {
            # `settings` is rendered into an ini file in the world-readable Nix
            # store, so neither the admin password nor the database encryption
            # key may ever be the value itself — only a reference to a runtime
            # file. nixpkgs asserts that `secret_key` is set at all; this is the
            # stricter half, that it is not set to a literal.
            name = "Grafana admin password and secret key are read from files, not the Nix store";
            assertion =
              let
                inherit (cfg.services.grafana.settings) security;
              in
              lib.hasPrefix "$__file{" security.admin_password && lib.hasPrefix "$__file{" security.secret_key;
          }
          {
            name = "Grafana has no self-registration and no anonymous access";
            assertion =
              (!cfg.services.grafana.settings.users.allow_sign_up)
              && (!cfg.services.grafana.settings."auth.anonymous".enabled);
          }
          {
            # A Grafana with no datasources is a Grafana nobody finishes setting
            # up; both are provisioned so a rebuilt server is immediately useful.
            name = "Grafana is provisioned with the Prometheus and Loki datasources";
            assertion =
              let
                p = cfg.services.grafana.provision;
                # Sorted, so reordering the list in grafana.nix (which only
                # affects display order in the UI) does not fail the check.
                types = lib.sort lib.lessThan (map (d: d.type) p.datasources.settings.datasources);
              in
              p.enable && lib.concatStringsSep "," types == "loki,prometheus";
          }
          {
            # Same guard as the Paperless one: without these oneshots loki and
            # grafana race zfs-mount.service and start against a missing
            # directory (or, worse, one shadowed by the unmounted pool).
            name = "Loki and Grafana directories are created after the ZFS pool is mounted";
            assertion =
              let
                loki = cfg.systemd.services.loki-data-dirs or null;
                grafana = cfg.systemd.services.grafana-data-dirs or null;
              in
              loki != null
              && builtins.elem "zfs-mount.service" loki.after
              && grafana != null
              && builtins.elem "zfs-mount.service" grafana.after;
          }
          {
            name = "ntfy enabled";
            assertion = cfg.services.ntfy-sh.enable;
          }
          {
            name = "ntfy public URL is HTTPS (TLS terminates at the reverse proxy)";
            assertion = lib.hasPrefix "https://" cfg.services.ntfy-sh.settings.base-url;
          }
          {
            # The counterpart of the Paperless exposure assertion, one step
            # weaker on purpose: ntfy IS public, but only through NPM. Its port
            # must still never join the globally-open set — the "WAN TCP surface
            # is exactly 80/443" assertion above is what enforces that.
            name = "ntfy listens on 2586 and never on the WAN directly";
            assertion =
              lib.hasSuffix ":2586" cfg.services.ntfy-sh.settings.listen-http
              && !(builtins.elem 2586 cfg.networking.firewall.allowedTCPPorts);
          }
          {
            # extraInputRules is an nftables-only option: under the iptables
            # backend these rules are silently dropped, so checking their text
            # without checking the backend would assert nothing.
            name = "ntfy admitted only from the podman bridge and the VPN (nftables backend)";
            assertion =
              let
                rule = "ip saddr { 10.88.0.0/16, 10.100.0.0/24 } tcp dport 2586 accept";
              in
              cfg.networking.nftables.enable && lib.hasInfix rule cfg.networking.firewall.extraInputRules;
          }
          {
            # The guard that makes publishing ntfy defensible at all: an open
            # instance lets anyone who guesses a topic name read the phone's
            # notifications or spam it.
            name = "ntfy is closed by default (deny-all, no self-signup)";
            assertion =
              cfg.services.ntfy-sh.settings.auth-default-access == "deny-all"
              && !cfg.services.ntfy-sh.settings.enable-signup;
          }
          {
            # Without this every request looks like it came from the proxy, so
            # rate limiting accounts the whole internet as a single visitor.
            name = "ntfy trusts the reverse proxy's forwarded-for header";
            assertion = cfg.services.ntfy-sh.settings.behind-proxy;
          }
          {
            # Must be asserted, not assumed: the upstream module defaults
            # attachment-cache-dir to a real path, so uploads are ON unless the
            # module explicitly blanks it out. A public file store that anyone
            # holding the publish token can fill is not what this box is for.
            name = "ntfy attachments disabled (no public upload target)";
            assertion = cfg.services.ntfy-sh.settings.attachment-cache-dir == "";
          }
          {
            # Pinned rather than inherited from upstream's stateVersion ladder.
            # An unpinned package that moves does not fail — dataDir is
            # /var/lib/postgresql/${psqlSchema}, so it would initialise a new,
            # empty cluster beside the old one. The major is asserted, not the
            # full version, so a minor bump from a lock update still passes.
            name = "PostgreSQL enabled on a pinned major version";
            assertion =
              cfg.services.postgresql.enable
              && lib.versions.major cfg.services.postgresql.package.version == "18";
          }
          {
            # `enableTCPIP = false` is not sufficient on its own: upstream
            # renders listen_addresses = "localhost" for it, which still binds
            # 127.0.0.1:5432. Empty means no TCP listener at all — which is what
            # makes the absence of any firewall rule correct rather than merely
            # untested.
            name = "PostgreSQL listens on the Unix socket only, never TCP";
            assertion =
              !cfg.services.postgresql.enableTCPIP && cfg.services.postgresql.settings.listen_addresses == "";
          }
          {
            # Nothing listens, so nothing may be admitted — by any of the three
            # routes this config uses. "WAN TCP surface is exactly 80/443" above
            # already covers allowedTCPPorts; the per-interface set and
            # extraInputRules are the two a future edit would actually reach for.
            name = "PostgreSQL opens no firewall port, on any interface";
            assertion =
              !(builtins.elem 5432 cfg.networking.firewall.allowedTCPPorts)
              && !(builtins.elem 5432 (cfg.networking.firewall.interfaces.wg0.allowedTCPPorts or [ ]))
              && !(lib.hasInfix "5432" cfg.networking.firewall.extraInputRules);
          }
          {
            # Socket-only is only safe because local connections are peer-
            # authenticated: a role is reachable by the system user of the same
            # name and by nobody else, so no service needs a password in sops.
            # This is upstream's default and postgresql.nix deliberately does not
            # restate it (`authentication` is types.lines — a definition appends
            # rather than replaces), so this assertion is what holds the property.
            name = "PostgreSQL local auth is peer, never trust";
            assertion =
              let
                hba = cfg.services.postgresql.authentication;
              in
              builtins.match "(.|\n)*local +all +all +peer(.|\n)*" hba != null && !(lib.hasInfix "trust" hba);
          }
          {
            # The SSD/pool split, same as Forgejo: the cluster is latency-bound
            # and every path under it needs tmpfiles rules, which cannot reach
            # the pool. Durability is the dump below, not the data directory.
            name = "PostgreSQL cluster stays on the SSD root";
            assertion = lib.hasPrefix "/var/lib/" cfg.services.postgresql.dataDir;
          }
          {
            # backupAll (which an empty `databases` selects) means pg_dumpall, so
            # roles and globals are captured too and new databases are covered
            # without editing the module.
            name = "PostgreSQL dumps all databases nightly onto the redundant ZFS pool";
            assertion =
              cfg.services.postgresqlBackup.enable
              && cfg.services.postgresqlBackup.backupAll
              && lib.hasPrefix "/hdd_pool_1/" cfg.services.postgresqlBackup.location;
          }
          {
            # Guards the ordering fix: postgresqlBackup declares its location
            # through systemd.tmpfiles, which runs before zfs-mount.service.
            name = "PostgreSQL dump directory is created after the ZFS pool is mounted";
            assertion =
              let
                unit = cfg.systemd.services.postgresql-dump-dirs or null;
              in
              unit != null && builtins.elem "zfs-mount.service" unit.after;
          }
        ];
      testLib = import "${nixpkgs}/nixos/lib/testing-python.nix" {
        inherit system pkgs;
      };

      # nixosTest node: the private-laptop host plus the home-manager module and
      # `inputs` that mkHost normally supplies.
      testNode = {
        imports = [
          home-manager.nixosModules.home-manager
          inputs.stylix.nixosModules.stylix
          inputs.sops-nix.nixosModules.sops
          ./hosts/private-laptop/default.nix
        ];
        _module.args.inputs = inputs;
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = { inherit inputs; };
        };
      };

      # Gaming test node: the desktop host with the chaotic module. Can't reuse
      # testNode, which boots private-laptop (no chaotic).
      gamingTestNode = {
        imports = [
          home-manager.nixosModules.home-manager
          inputs.stylix.nixosModules.stylix
          inputs.sops-nix.nixosModules.sops
          chaotic.nixosModules.default
          ./hosts/desktop/default.nix
        ];
        _module.args.inputs = inputs;
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = { inherit inputs; };
        };
      };

      # Forgejo test node: the forgejo module on its own, not the home-server
      # host — that host is untestable in QEMU (ZFS pool, VPN-only SSH, NFS),
      # which is why it has assertions but no VM test. Dumps are forced off
      # because their target lives on the ZFS pool.
      forgejoTestNode = {
        imports = [ ./modules/nixos/server/forgejo.nix ];
        services.forgejo.dump.enable = lib.mkForce false;
        # No nftables line here on purpose: forgejo.nix defaults it on itself,
        # since its source-restricted rules need that backend. This node is the
        # check that the module really is self-contained.
        environment.systemPackages = [ pkgs.curl ];
        virtualisation = {
          memorySize = 2048;
          diskSize = 4096;
        };
      };

      # Private half of the &test_fixture recipient in .sops.yaml. It guards
      # nothing real — it decrypts only secrets/fixtures/*, which hold a known
      # sentinel — so committing it is deliberate. Shared by test-secrets and
      # test-paperless.
      testAgeKey = "AGE-SECRET-KEY-1ZTVVG7CHXYCL2JLJ6ADJ3JDMQ32AQPEWHHYNZ3E9MVM7KA6QZQFQC2JGGK";

      # Paperless test node: the paperless module on its own, for the same reason
      # forgejoTestNode exists. The pool paths can't be had in a VM, so they are
      # redirected to /var/lib and the ZFS oneshot is dropped — its ordering is
      # what the host assertions cover.
      #
      # The sops secret is redirected to the test fixture rather than forced away:
      # `services.paperless.passwordFile` reads it, and `lib.mkForce null` cannot
      # rescue that — the module system evaluates every definition's value to read
      # its priority, so a missing `sops.secrets` attr throws before the override
      # is ever applied. Pointing it at the fixture keeps the admin-creation path
      # exercised for real instead of stubbed out.
      paperlessTestNode = {
        imports = [
          inputs.sops-nix.nixosModules.sops
          ./modules/nixos/server/paperless.nix
        ];

        environment.etc."test-age-key.txt" = {
          text = testAgeKey + "\n";
          mode = "0400";
        };

        sops = {
          # The VM's fresh host key is not a fixture recipient; use the injected
          # test identity instead (same override as test-secrets).
          age = {
            sshKeyPaths = lib.mkForce [ ];
            keyFile = "/etc/test-age-key.txt";
          };
          gnupg.sshKeyPaths = lib.mkForce [ ];
          secrets.paperless-admin-password = {
            sopsFile = lib.mkForce ./secrets/fixtures/test.yaml;
            key = "fixture_secret";
          };
        };

        services.paperless = {
          dataDir = lib.mkForce "/var/lib/paperless";
          mediaDir = lib.mkForce "/var/lib/paperless/media";
          consumptionDir = lib.mkForce "/var/lib/paperless/consume";
          exporter.directory = lib.mkForce "/var/lib/paperless/export";
        };
        # Not `enable = false`: a disabled unit is *masked* (symlinked to
        # /dev/null) while its requiredBy symlinks are still emitted, so all six
        # paperless units would Require a masked unit and refuse to start.
        # Clearing the edges leaves it defined but unreferenced, and upstream's
        # tmpfiles rules create the /var/lib paths this node uses instead.
        systemd.services.paperless-data-dirs = {
          requires = lib.mkForce [ ];
          after = lib.mkForce [ ];
          before = lib.mkForce [ ];
          requiredBy = lib.mkForce [ ];
        };
        environment.systemPackages = [ pkgs.curl ];
        virtualisation = {
          memorySize = 4096;
          diskSize = 8192;
        };
      };

      # ntfy test node: the module on its own, for the same reason forgejoTestNode
      # exists. Nothing is overridden — there is no pool path and no sops secret
      # to redirect, so the node runs the production settings verbatim, which is
      # what makes the deny-all assertions in the test script meaningful.
      #
      # No nftables line here on purpose: ntfy.nix defaults it on itself, since
      # its source-restricted rule needs that backend. This node is the check that
      # the module really is self-contained.
      ntfyTestNode = {
        imports = [ ./modules/nixos/server/ntfy.nix ];
        environment.systemPackages = [ pkgs.curl ];
        virtualisation = {
          memorySize = 2048;
          diskSize = 4096;
        };
      };

      # Observability test node: the three modules on their own, for the same
      # reason forgejoTestNode and paperlessTestNode exist.
      #
      # Unlike those two the pool paths are NOT redirected. /hdd_pool_1 is just
      # a directory on the VM's scratch root disk here, and the data-dirs
      # oneshots create it — so the real paths, ownership and modes the server
      # uses are exercised. Only their ordering against zfs-mount.service (a
      # unit that does not exist in the VM) is cleared; the before/requiredBy
      # edges stay, which is also why the units are edited rather than disabled:
      # a disabled unit is *masked* while its requiredBy symlinks are still
      # emitted, so loki and grafana would Require a masked unit and refuse to
      # start.
      observabilityTestNode = {
        imports = [
          inputs.sops-nix.nixosModules.sops
          ./modules/nixos/server/metrics.nix
          ./modules/nixos/server/logs.nix
          ./modules/nixos/server/grafana.nix
        ];

        environment.etc."test-age-key.txt" = {
          text = testAgeKey + "\n";
          mode = "0400";
        };

        sops = {
          # The VM's fresh host key is not a fixture recipient; use the injected
          # test identity instead (same override as test-secrets).
          age = {
            sshKeyPaths = lib.mkForce [ ];
            keyFile = "/etc/test-age-key.txt";
          };
          gnupg.sshKeyPaths = lib.mkForce [ ];
          # Redirected to the fixture rather than forced away, so the sops path
          # is exercised end to end: the test logs into Grafana with the
          # fixture's plaintext. The secret key rides along on the same fixture
          # value — it only has to be *a* key for Grafana to start.
          secrets = {
            grafana-admin-password = {
              sopsFile = lib.mkForce ./secrets/fixtures/test.yaml;
              key = "fixture_secret";
            };
            grafana-secret-key = {
              sopsFile = lib.mkForce ./secrets/fixtures/test.yaml;
              key = "fixture_secret";
            };
          };
        };

        # Seed the pool root in the broken state the real box was found in: the
        # mountpoint owned by a non-service user at 0750, which is what
        # `zfs.extraPools` leaves behind when the pool predates this config.
        # tmpfiles runs long before the data-dirs oneshots, so grafana.service
        # only starts if one of them really does chmod the root — without that,
        # systemd fails at CHDIR into WorkingDirectory. Creating it root:root
        # 0755 (which is what the VM would do on its own) tests nothing.
        systemd.tmpfiles.rules = [ "d /hdd_pool_1 0750 nobody nogroup -" ];

        # Virtio disks expose no SMART data, and smartctl_exporter exits when
        # `smartctl --scan` finds nothing. metrics.nix drops its scrape config
        # along with it, so this leaves no permanently-down target behind.
        services.prometheus.exporters.smartctl.enable = lib.mkForce false;

        systemd.services = {
          loki-data-dirs = {
            requires = lib.mkForce [ ];
            after = lib.mkForce [ ];
          };
          grafana-data-dirs = {
            requires = lib.mkForce [ ];
            after = lib.mkForce [ ];
          };
        };

        environment.systemPackages = [
          pkgs.curl
          pkgs.jq
        ];
        virtualisation = {
          memorySize = 4096;
          diskSize = 8192;
        };
      };

      # PostgreSQL test node: the module on its own, for the same reason
      # forgejoTestNode and paperlessTestNode exist — the home-server host cannot
      # boot in QEMU. Only the dump location moves off the pool; the cluster
      # already lives at the module's real /var/lib path, so the thing under test
      # is the production configuration.
      #
      # No sops fixture is needed here: peer auth means the module holds no
      # secret at all, which is itself part of the design.
      postgresqlTestNode = {
        imports = [ ./modules/nixos/server/postgresql.nix ];

        services.postgresqlBackup.location = lib.mkForce "/var/lib/postgresql-dump";

        # Same reasoning as paperlessTestNode: not `enable = false`, which masks
        # the unit (symlink to /dev/null) while still emitting its requiredBy
        # edge, leaving postgresqlBackup Requiring a masked unit. Clearing the
        # edges leaves it defined but unreferenced, and upstream's tmpfiles rule
        # creates the /var/lib location this node uses instead.
        systemd.services.postgresql-dump-dirs = {
          requires = lib.mkForce [ ];
          after = lib.mkForce [ ];
          before = lib.mkForce [ ];
          requiredBy = lib.mkForce [ ];
        };

        environment.systemPackages = [
          pkgs.iproute2 # ss, for the "no TCP listener" check
          pkgs.zstd # to read the dump back
        ];
        virtualisation = {
          memorySize = 2048;
          diskSize = 4096;
        };
      };
    in
    {
      formatter.${system} = pkgs.nixfmt;

      devShells.${system} = {
        default = pkgs.mkShell {
          # Installs the gitleaks pre-commit hook into .git/hooks on shell entry.
          inherit (preCommitCheck) shellHook;
          packages =
            (with pkgs; [
              nil
              statix
              deadnix
              nixfmt
              # Edit/re-key sops files and convert SSH host keys to age.
              sops
              ssh-to-age
              age
            ])
            ++ preCommitCheck.enabledPackages;
        };

        # Per-language project shells. `nix develop ~/desktop-nix#rust`, or
        # scaffold with `nix flake init -t ~/desktop-nix#rust`.
        rust = pkgs.mkShell {
          packages = with pkgs; [
            cargo
            rustc
            rustfmt
            clippy
            cargo-nextest
            bacon
            rust-analyzer
          ];
        };
        go = pkgs.mkShell {
          packages = with pkgs; [
            go
            gopls
            gotools
            gofumpt
          ];
        };
        node = pkgs.mkShell {
          packages = with pkgs; [
            nodejs
            typescript-language-server
          ];
        };
        python = pkgs.mkShell {
          packages = with pkgs; [
            python3
            uv
            ruff
            python3Packages.python-lsp-server
          ];
        };
      };

      checks.${system} = {
        # Secret scanning: same gitleaks run the .git/hooks pre-commit uses, so
        # local `nix flake check` and CI fail on a committed secret too.
        pre-commit-check = preCommitCheck;

        statix-check =
          pkgs.runCommand "statix-check"
            {
              nativeBuildInputs = [ pkgs.statix ];
            }
            ''
              statix check ${./.}
              touch $out
            '';

        deadnix-check =
          pkgs.runCommand "deadnix-check"
            {
              nativeBuildInputs = [ pkgs.deadnix ];
            }
            ''
              deadnix --fail ${./.}
              touch $out
            '';

        # Formatting is gated here so local `nix flake check` and CI stay identical.
        nixfmt-check =
          pkgs.runCommand "nixfmt-check"
            {
              nativeBuildInputs = [ pkgs.nixfmt ];
            }
            ''
              find ${./.} -name '*.nix' -print0 | xargs -0 nixfmt --check
              touch $out
            '';

        # Dev devShell smoke checks: each toolchain compiles/runs a trivial
        # hello-world offline, so a broken per-language shell fails the check.
        dev-node-check = pkgs.runCommand "dev-node-check" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
          node -e 'process.exit(0)'
          touch $out
        '';

        dev-python-check = pkgs.runCommand "dev-python-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          python3 -c 'assert 1 + 1 == 2'
          touch $out
        '';

        dev-go-check = pkgs.runCommand "dev-go-check" { nativeBuildInputs = [ pkgs.go ]; } ''
          export HOME="$TMPDIR" GOCACHE="$TMPDIR/go-cache" GOPROXY=off GOFLAGS=-mod=mod
          cat > hello.go <<'EOF'
          package main
          import "fmt"
          func main() { fmt.Println("hello") }
          EOF
          go run hello.go
          touch $out
        '';

        dev-rust-check =
          pkgs.runCommand "dev-rust-check"
            {
              nativeBuildInputs = [
                pkgs.cargo
                pkgs.rustc
                pkgs.cargo-nextest
                pkgs.gcc # cc — rustc needs a linker to build the test binary
              ];
            }
            ''
              export HOME="$TMPDIR" CARGO_HOME="$TMPDIR/cargo"
              # `cargo new --lib` ships a passing `it_works` test; just build+run it.
              cargo new --lib --vcs none hello
              cd hello
              cargo nextest run --offline
              touch $out
            '';

        # Eval-level checks for the per-host deltas that CI's toplevel builds
        # don't assert (chaotic only on desktop, kanshi profile ordering, …).
        host-assertions-private-laptop =
          let
            cfg = hosts.private-laptop.config;
          in
          mkHostCheck "private-laptop"
            (
              baseAssertions "private-laptop" cfg
              ++ [
                {
                  name = "chaotic module NOT loaded";
                  assertion = !(hosts.private-laptop.options ? chaotic);
                }
                {
                  name = "kanshi has only the laptop-internal fallback";
                  assertion = kanshiProfileNames cfg == [ "laptop-internal" ];
                }
                # Gaming stack is desktop-only — the Intel laptop must not pull
                # in scx, Steam or 32-bit graphics.
                {
                  name = "no gaming stack (scx + steam disabled)";
                  assertion =
                    !cfg.services.scx.enable && !cfg.programs.steam.enable && !cfg.hardware.graphics.enable32Bit;
                }
                # Waydroid is opt-in on private-laptop.
                {
                  name = "waydroid enabled";
                  assertion = cfg.virtualisation.waydroid.enable;
                }
              ]
            )
            ''
              ${hyprlandLuaCheck "private-laptop"}
              grep -q 'output "eDP-1" enable' ${kanshiConfig "private-laptop"}
            '';

        host-assertions-work-laptop =
          let
            cfg = hosts.work-laptop.config;
          in
          mkHostCheck "work-laptop"
            (
              baseAssertions "work-laptop" cfg
              ++ [
                {
                  name = "chaotic module NOT loaded";
                  assertion = !(hosts.work-laptop.options ? chaotic);
                }
                # Gaming stack is desktop-only.
                {
                  name = "no gaming stack (scx + steam disabled)";
                  assertion =
                    !cfg.services.scx.enable && !cfg.programs.steam.enable && !cfg.hardware.graphics.enable32Bit;
                }
                # Waydroid is deliberately absent from the work laptop.
                {
                  name = "waydroid NOT enabled";
                  assertion = !cfg.virtualisation.waydroid.enable;
                }
                {
                  name = "kanshi: docked profiles before fallback";
                  assertion =
                    kanshiProfileNames cfg == [
                      "work-laptop-docked-dual"
                      "work-laptop-docked-hdmi"
                      "laptop-internal"
                    ];
                }
              ]
            )
            ''
              ${hyprlandLuaCheck "work-laptop"}
              conf=${kanshiConfig "work-laptop"}
              grep -q 'output "DP-5" position 0,0' "$conf"
              grep -q 'output "DP-6" position 2560,0' "$conf"
              grep -q 'output "HDMI-A-1" position 1920,0' "$conf"
              # The fallback must be LAST so docked setups match first.
              test "$(grep '^profile' "$conf" | tail -1)" = 'profile laptop-internal {'
            '';

        host-assertions-desktop =
          let
            cfg = hosts.desktop.config;
          in
          mkHostCheck "desktop"
            (
              baseAssertions "desktop" cfg
              ++ [
                {
                  name = "chaotic module loaded (chaotic.nyx options present)";
                  assertion = (hosts.desktop.options ? chaotic) && (hosts.desktop.options.chaotic ? nyx);
                }
                # Gaming stack, desktop-only.
                {
                  name = "CachyOS kernel selected";
                  assertion = cfg.boot.kernelPackages.kernel == hosts.desktop.pkgs.linuxPackages_cachyos.kernel;
                }
                {
                  name = "sched-ext scx_lavd enabled";
                  assertion = cfg.services.scx.enable && cfg.services.scx.scheduler == "scx_lavd";
                }
                {
                  name = "Steam enabled with 32-bit graphics + gamemode";
                  assertion =
                    cfg.programs.steam.enable && cfg.hardware.graphics.enable32Bit && cfg.programs.gamemode.enable;
                }
                {
                  # The host's performance mode: PPD has no driver on this CPU
                  # (no CPPC/EPP), so gamemode is what raises the governor.
                  name = "gamemode raises the CPU governor and AMD perf level";
                  assertion =
                    cfg.programs.gamemode.settings.general.desiredgov == "performance"
                    && cfg.programs.gamemode.settings.gpu.amd_performance_level == "high";
                }
                {
                  name = "amdgpu overdrive unlocked for LACT";
                  assertion = builtins.elem "amdgpu.ppfeaturemask=0xffffffff" cfg.boot.kernelParams;
                }
                {
                  name = "MangoHud enabled in maudi's home";
                  assertion = cfg.home-manager.users.maudi.programs.mangohud.enable;
                }
                # Waydroid is opt-in on desktop.
                {
                  name = "waydroid enabled";
                  assertion = cfg.virtualisation.waydroid.enable;
                }
                {
                  name = "kanshi: dual-head profile before fallback";
                  assertion =
                    kanshiProfileNames cfg == [
                      "desktop"
                      "laptop-internal"
                    ];
                }
              ]
            )
            ''
              ${hyprlandLuaCheck "desktop"}
              conf=${kanshiConfig "desktop"}
              grep -q 'output "DP-3" mode 2560x1440@144 position 0,0' "$conf"
              grep -q 'output "DP-2" mode 1920x1080@60 position 2560,0' "$conf"
              test "$(grep '^profile' "$conf" | tail -1)" = 'profile laptop-internal {'
            '';

        # Home-server eval assertions: it uses serverAssertions (not
        # baseAssertions — no desktop stack, and it enables SSH). A nixosTest is
        # omitted because VPN-only SSH, ZFS and NFS can't run in a QEMU node.
        host-assertions-home-server =
          let
            cfg = hosts.home-server.config;
          in
          mkHostCheck "home-server" (
            serverAssertions "home-server" cfg
            ++ [
              # No desktop/workstation stack leaked in via a stray import.
              {
                name = "no Hyprland / desktop session on the server";
                assertion = !cfg.programs.hyprland.enable;
              }
              {
                name = "stylix disabled (headless, no theming)";
                assertion = !cfg.stylix.enable;
              }
              {
                name = "chaotic module NOT loaded";
                assertion = !(hosts.home-server.options ? chaotic);
              }
            ]
          ) "";

        # Boot private-laptop config, assert multi-user.target.
        test-boot-private-laptop = testLib.makeTest {
          name = "boot-private-laptop";
          nodes.machine = testNode;
          testScript = ''
            machine.wait_for_unit("multi-user.target")
          '';
        };

        # Base system module: user + fish login shell, NetworkManager, PipeWire,
        # and that the configured fonts actually land. The host imports the base
        # module, so booting it exercises modules/nixos/base.
        test-base-system = testLib.makeTest {
          name = "base-system";
          nodes.machine = testNode;
          testScript = ''
            machine.wait_for_unit("multi-user.target")

            # User exists with fish as its login shell.
            machine.succeed("id maudi")
            machine.succeed("getent passwd maudi | grep -q 'bin/fish'")

            # NetworkManager is up.
            machine.wait_for_unit("NetworkManager.service")

            # PipeWire is wired into the user session (socket unit installed).
            machine.succeed("test -e /etc/systemd/user/sockets.target.wants/pipewire.socket")

            # Fonts actually land.
            machine.succeed("fc-list | grep -i 'JetBrainsMono Nerd Font'")

            # Shell & CLI environment: the maudi home generation built fish + configs.
            machine.wait_for_unit("home-manager-maudi.service")

            # Configs rendered for fish, kitty, fastfetch and lazygit.
            machine.succeed("test -e /home/maudi/.config/fish/config.fish")
            machine.succeed("test -e /home/maudi/.config/kitty/kitty.conf")
            machine.succeed("test -e /home/maudi/.config/fastfetch/config.jsonc")
            machine.succeed("test -e /home/maudi/.config/lazygit/config.yml")

            # Neovim (nixvim) is installed and the ember colorscheme loads cleanly
            # headless. `auto=` records what nixvim applied at startup, for the CI log.
            machine.succeed("test -x /etc/profiles/per-user/maudi/bin/nvim")
            machine.succeed(
                "su maudi -c '/etc/profiles/per-user/maudi/bin/nvim --headless "
                "\"+lua local auto = tostring(vim.g.colors_name); "
                "local ok, err = pcall(vim.cmd.colorscheme, [[ember]]); "
                "local f = io.open([[/tmp/cs]], [[w]]); "
                "f:write(([[auto=%s name=%s ok=%s err=%s]]):format("
                "auto, tostring(vim.g.colors_name), tostring(ok), tostring(err))); "
                "f:close()\" +qa'"
            )
            cs = machine.succeed("cat /tmp/cs")
            print("neovim colorscheme smoke: " + cs)
            assert "name=ember" in cs, "ember colorscheme did not apply: " + cs

            # fish starts cleanly and the ported aliases/functions resolve.
            machine.succeed("su maudi -c 'fish -ic \"true\"'")
            machine.succeed("su maudi -c 'fish -ic \"type ls\"' | grep -q eza")
            machine.succeed("su maudi -c 'fish -ic \"type cat\"' | grep -q bat")
            machine.succeed(
                "su maudi -c 'fish -ic \"functions -q mkcd; and functions -q gst\"'"
            )

            # starship is installed and fish's interactive init sources it.
            machine.succeed("test -x /etc/profiles/per-user/maudi/bin/starship")
            machine.succeed("grep -q 'starship init fish' /home/maudi/.config/fish/config.fish")

            # The migrated CLI tools are on maudi's PATH.
            machine.succeed(
                "for b in eza bat fd rg btop zoxide delta tree fzf lazygit fastfetch; do "
                "test -x /etc/profiles/per-user/maudi/bin/$b; done"
            )

            # Hardening: SSH daemon off, firewall active.
            machine.fail("systemctl is-active sshd")
            machine.succeed("nft list ruleset | grep -q 'type filter hook input'")

            # Security-event logging: auditd up with rules loaded, sudo logs to
            # its file, journal persistent.
            machine.wait_for_unit("auditd.service")
            # Rules load at sysinit; assert with `succeed` (not a long
            # wait_until_succeeds) so a regression fails fast.
            machine.succeed("systemctl is-active audit-rules-nixos.service")
            machine.succeed("auditctl -l | grep -q priv_esc")
            machine.succeed("grep -q 'logfile=/var/log/sudo.log' /etc/sudoers")
            # Storage=persistent makes journald keep logs under /var/log/journal.
            machine.succeed("test -d /var/log/journal")
          '';
        };

        # Desktop stack: Hyprland session registration, greeter, polkit agent and
        # the maudi home-manager generation (Noctalia shell).
        test-desktop = testLib.makeTest {
          name = "desktop";
          nodes.machine = testNode;
          testScript = ''
            machine.wait_for_unit("multi-user.target")

            # Greeter is up and the Hyprland session binary is installed.
            machine.wait_for_unit("greetd.service")
            machine.succeed("test -x /run/current-system/sw/bin/Hyprland")

            # Power-profile backend for Noctalia's power widget/OSD. It is D-Bus
            # activated (inactive at boot), so verify it is installed and
            # actually starts rather than waiting for it.
            machine.succeed("systemctl start power-profiles-daemon.service")
            # UPower backs Noctalia's battery widget + idle handling.
            machine.succeed("systemctl start upower.service")

            # maudi's home generation built the user desktop: the Noctalia shell
            # binary and the polkit agent unit are present in the profile.
            machine.succeed("test -x /etc/profiles/per-user/maudi/bin/noctalia")
            machine.succeed(
                "test -e /etc/profiles/per-user/maudi/share/systemd/user/hyprpolkitagent.service"
            )

            # The Hyprland user config was rendered by home-manager.
            machine.wait_for_unit("home-manager-maudi.service")
            # Hyprland 0.56+ reads hyprland.lua only; hyprland.conf is never loaded.
            machine.succeed("test -e /home/maudi/.config/hypr/hyprland.lua")
            machine.fail("test -e /home/maudi/.config/hypr/hyprland.conf")
            # Hyprland binds drive Noctalia over IPC (launcher toggle).
            machine.succeed("grep -q 'panel-toggle launcher' /home/maudi/.config/hypr/hyprland.lua")
            # The session target must be started from the config, or nothing
            # wired to it (noctalia, kanshi) ever comes up.
            machine.succeed(
                "grep -q 'systemctl --user start hyprland-session.target' "
                "/home/maudi/.config/hypr/hyprland.lua"
            )

            # kanshi: config rendered, service wired to hyprland-session.target.
            machine.succeed("test -e /home/maudi/.config/kanshi/config")
            machine.succeed("grep -q 'profile laptop-internal' /home/maudi/.config/kanshi/config")
            machine.succeed(
                "test -e /home/maudi/.config/systemd/user/hyprland-session.target.wants/kanshi.service"
            )

            # Noctalia shell: user service unit installed and wired to the
            # graphical session, and its TOML config was rendered + validated.
            machine.succeed("test -e /home/maudi/.config/systemd/user/noctalia.service")
            machine.succeed(
                "test -e /home/maudi/.config/systemd/user/graphical-session.target.wants/noctalia.service"
            )
            machine.succeed("test -e /home/maudi/.config/noctalia/config.toml")
            # Theming (wallpaper-derived) and idle (auto-suspend) settings landed.
            machine.succeed("grep -q 'source = \"wallpaper\"' /home/maudi/.config/noctalia/config.toml")
            machine.succeed("grep -q 'systemctl suspend' /home/maudi/.config/noctalia/config.toml")

            # Plugins: the declarative path source is wired (no runtime git clone)
            # and the Nix Monitor widget is placed in the bar.
            machine.succeed(
                "grep -q 'avivbintangaringga/nix-monitor:nix-monitor' /home/maudi/.config/noctalia/config.toml"
            )
            machine.succeed("grep -q 'noctalia-plugins' /home/maudi/.config/noctalia/config.toml")
            machine.succeed("grep -q 'auto_update = false' /home/maudi/.config/noctalia/config.toml")
            # Noctalia scans the SUBDIRS of the source location for plugin.toml, so
            # each plugin must sit in its own dir under it, manifest + entry present.
            # The manifest must also declare `plugin_api` — without it current
            # Noctalia silently skips the plugin at scan time.
            machine.succeed(
                "loc=$(sed -n 's/.*location = \"\\([^\"]*\\)\".*/\\1/p' /home/maudi/.config/noctalia/config.toml); "
                "test -f \"$loc/nix-monitor/plugin.toml\" && test -f \"$loc/nix-monitor/nix_monitor.luau\" && "
                "grep -q '^plugin_api' \"$loc/nix-monitor/plugin.toml\""
            )

            # stylix still themes the apps from the wallpaper: kitty config rendered.
            machine.succeed("test -e /home/maudi/.config/kitty/kitty.conf")

            # SUPER+RETURN terminal target is installed.
            machine.succeed("test -x /etc/profiles/per-user/maudi/bin/kitty")

            # XDG portals registered system-wide (Hyprland + gtk file pickers).
            machine.succeed(
                "ls /run/current-system/sw/share/xdg-desktop-portal/portals | grep -qi hyprland"
            )
            machine.succeed(
                "ls /run/current-system/sw/share/xdg-desktop-portal/portals | grep -qi gtk"
            )
          '';
        };

        # Dev containers: run a container from a store-loaded image (the VM has no
        # network) and verify the docker→podman compat shim and podman-compose.
        test-podman =
          let
            image = pkgs.dockerTools.buildImage {
              name = "hello";
              tag = "test";
              copyToRoot = pkgs.buildEnv {
                name = "hello-root";
                paths = [ pkgs.coreutils ];
                pathsToLink = [ "/bin" ];
              };
              config.Cmd = [ "/bin/true" ];
            };
          in
          testLib.makeTest {
            name = "podman";
            nodes.machine = testNode;
            testScript = ''
              machine.wait_for_unit("multi-user.target")

              # podman + podman-compose on PATH; docker is the podman compat
              # shim — verify it resolves to the podman binary (the dockerCompat
              # `docker --version` string is not guaranteed to mention podman).
              machine.succeed("podman --version")
              machine.succeed("podman-compose --version")
              machine.succeed("realpath $(command -v docker) | grep -qi podman")

              # Load the locally-built image and run it (rootful, no network).
              machine.succeed("podman load -i ${image}")
              machine.succeed("podman run --rm --network=none hello:test")
            '';
          };

        # Forgejo: the service comes up, serves the web UI and the API, runs its
        # built-in git SSH server on 2222, and the generated app.ini carries the
        # settings the design depends on (single-user forge, Actions on, GitHub
        # as the action namespace, HTTPS public URL).
        test-forgejo = testLib.makeTest {
          name = "forgejo";
          nodes.machine = forgejoTestNode;
          testScript = ''
            machine.wait_for_unit("forgejo.service")
            machine.wait_for_open_port(4000)

            machine.succeed("curl -fsS http://localhost:4000/api/healthz")
            machine.succeed("curl -fsS http://localhost:4000/api/v1/version | grep -q version")
            # The web UI answers. LANDING_PAGE=explore redirects, so follow it
            # rather than grepping the (empty) redirect body.
            machine.succeed(
                "test $(curl -fsSL -o /dev/null -w '%{http_code}' http://localhost:4000/) = 200"
            )

            # Built-in SSH server, not host sshd (which is off here).
            machine.wait_for_open_port(2222)

            conf = "/var/lib/forgejo/custom/conf/app.ini"
            machine.succeed(f"grep -qE '^DISABLE_REGISTRATION *= *true' {conf}")
            machine.succeed(f"grep -qE '^DEFAULT_ACTIONS_URL *= *github' {conf}")
            machine.succeed(f"grep -qE '^ROOT_URL *= *https://' {conf}")
            machine.succeed(f"grep -qE '^START_SSH_SERVER *= *true' {conf}")
          '';
        };

        # Paperless: the stack comes up (redis, scheduler, workers, web), the UI
        # answers on :28981, and the generated environment carries the settings
        # the design depends on (German+English OCR, the VPN URL that populates
        # CSRF_TRUSTED_ORIGINS, and no local postgres).
        test-paperless = testLib.makeTest {
          name = "paperless";
          nodes.machine = paperlessTestNode;
          testScript = ''
            machine.wait_for_unit("redis-paperless.service")
            machine.wait_for_unit("paperless-scheduler.service")
            machine.wait_for_unit("paperless-web.service")
            machine.wait_for_open_port(28981)

            # The login page renders. ALLOWED_HOSTS stays ["*"], so reaching it
            # over localhost works even though PAPERLESS_URL names the VPN
            # address — the URL only feeds CSRF/CORS.
            machine.succeed(
                "test $(curl -fsSL -o /dev/null -w '%{http_code}' http://localhost:28981/accounts/login/) = 200"
            )

            # Consumer and task queue are part of the stack, not optional extras.
            machine.wait_for_unit("paperless-consumer.service")
            machine.wait_for_unit("paperless-task-queue.service")

            # Settings that the archive's behaviour depends on.
            env = machine.succeed("systemctl show -p Environment paperless-web.service")
            assert "PAPERLESS_OCR_LANGUAGE=deu+eng" in env, env
            assert "PAPERLESS_URL=http://10.100.0.1:28981" in env, env
            # SQLite, not postgres: no DBENGINE override is emitted.
            assert "PAPERLESS_DBENGINE" not in env, env

            # The exporter is wired as a timer-driven unit.
            machine.succeed("systemctl cat paperless-exporter.service")
            machine.succeed("systemctl list-timers --all | grep -q paperless-exporter")

            # passwordFile reached the scheduler as a credential and the admin
            # account was created from it — the sops path, exercised end to end.
            machine.succeed("test -e /run/secrets/paperless-admin-password")
            machine.succeed("grep -q '^admin:' /var/lib/paperless/superuser-state")
          '';
        };

        # ntfy: the service comes up, the health endpoint answers, the closed-by-
        # default posture actually denies an anonymous publish, and an
        # authenticated publish→poll round trip works. The last part is the point:
        # an open port proves nothing about a server whose whole design is that
        # only authorized clients may read or write a topic.
        test-ntfy = testLib.makeTest {
          name = "ntfy";
          nodes.machine = ntfyTestNode;
          testScript = ''
            import json

            machine.wait_for_unit("ntfy-sh.service")
            machine.wait_for_open_port(2586)

            # Health is the one endpoint that answers without credentials.
            health = json.loads(machine.succeed("curl -fsS http://localhost:2586/v1/health"))
            assert health["healthy"], health

            # auth-default-access = deny-all, before any user exists: an
            # anonymous read is refused. ntfy answers 403 with a JSON body and
            # curl -f then exits non-zero, so assert on the body rather than
            # just "it failed" — a connection refused would look the same.
            denied = json.loads(machine.succeed("curl -sS 'http://localhost:2586/alerts/json?poll=1'"))
            assert denied["http"] == 403, denied
            machine.fail("curl -fsS -d hello http://localhost:2586/alerts")

            # Bootstrap a publisher the way INSTALL.md does. NTFY_PASSWORD is
            # what makes `ntfy user add` non-interactive — there is no flag —
            # and the commands run as root because DynamicUser puts the auth db
            # under /var/lib/private (see the note in ntfy.nix).
            machine.succeed("NTFY_PASSWORD=testpass ntfy user add --role=user --ignore-exists svc")
            machine.succeed("ntfy access svc alerts rw")

            # Round trip: publish as that user, then poll the message back out.
            machine.succeed("curl -fsS -u svc:testpass -d 'scrub found errors' http://localhost:2586/alerts")
            notif = json.loads(
                machine.succeed("curl -fsS -u svc:testpass 'http://localhost:2586/alerts/json?poll=1'")
            )
            assert notif["message"] == "scrub found errors", notif

            # The ACL is per topic, not a blanket grant: the same credentials
            # must not reach a topic they were never given access to.
            machine.fail("curl -fsS -u svc:testpass -d nope http://localhost:2586/other")

            # The settings the design depends on reached the rendered config.
            # Matched loosely — the YAML writer is free to quote scalars.
            conf = "/etc/ntfy/server.yml"
            machine.succeed(f"grep -qE '^base-url:.*https://ntfy\\.mauderer\\.work' {conf}")
            machine.succeed(f"grep -qE '^auth-default-access:.*deny-all' {conf}")
            machine.succeed(f"grep -qE '^behind-proxy: *true' {conf}")
            machine.succeed(f"grep -qE '^enable-signup: *false' {conf}")
            # Attachments stay off: the key is present (upstream defaults it to a
            # path) but must name no directory at all.
            machine.fail(f"grep -qE '^attachment-cache-dir:.*/' {conf}")
            # Upstream forwarding (iOS only) is off, so no topic hash leaves the box.
            machine.fail(f"grep -q upstream-base-url {conf}")
          '';
        };

        # Observability: the whole stack comes up, the pool layout is created
        # with the ownership every service module has to agree on, Prometheus
        # scrapes every target it declares, Grafana accepts the sops-held
        # password and carries both provisioned datasources, and a log line
        # makes the full journal -> Alloy -> Loki -> query round trip.
        test-observability = testLib.makeTest {
          name = "observability";
          nodes.machine = observabilityTestNode;
          testScript = ''
            machine.wait_for_unit("prometheus.service")
            machine.wait_for_unit("prometheus-node-exporter.service")
            machine.wait_for_unit("loki.service")
            machine.wait_for_unit("alloy.service")
            machine.wait_for_unit("grafana.service")

            machine.wait_for_open_port(9090)
            machine.wait_for_open_port(3100)
            machine.wait_for_open_port(3030)

            # The data-dirs oneshots ran: the pool layout exists with the 0755
            # on the shared parent that npm/forgejo/paperless/loki/grafana all
            # have to leave behind, and 0750 service-owned subtrees.
            # The pool root itself included: the node seeds it 0750 nobody, so
            # this is 755 only because a data-dirs oneshot widened it.
            machine.succeed("stat -c '%a' /hdd_pool_1 | grep -qx 755")
            machine.succeed("stat -c '%U' /hdd_pool_1 | grep -qx nobody")
            machine.succeed("stat -c '%a' /hdd_pool_1/services | grep -qx 755")
            machine.succeed("stat -c '%U %a' /hdd_pool_1/services/loki | grep -qx 'loki 750'")
            machine.succeed("stat -c '%U %a' /hdd_pool_1/services/grafana | grep -qx 'grafana 750'")
            machine.succeed("test -d /hdd_pool_1/services/loki/chunks")
            machine.succeed("test -d /hdd_pool_1/services/loki/tsdb-index")

            # Prometheus and the node exporter are loopback-bound, not 0.0.0.0 —
            # the property the host assertions state, checked against a live
            # listening socket.
            machine.succeed("ss -ltn | grep -q '127.0.0.1:9090'")
            machine.succeed("ss -ltn | grep -q '127.0.0.1:9100'")
            machine.fail("ss -ltn | grep -q '0.0.0.0:9090'")

            # Hardware metrics land, including the opt-in systemd collector that
            # makes a failed unit visible on a dashboard.
            metrics = machine.succeed("curl -fsS http://127.0.0.1:9100/metrics")
            for name in [
                "node_cpu_seconds_total",
                "node_filesystem_size_bytes",
                "node_memory_MemTotal_bytes",
                "node_systemd_unit_state",
            ]:
                assert name in metrics, "missing " + name

            # Every declared scrape target is healthy. The first scrape takes an
            # interval, hence wait_until_succeeds.
            machine.wait_until_succeeds(
                "curl -fsS 'http://127.0.0.1:9090/api/v1/targets?state=active' "
                "| jq -e '[.data.activeTargets[] | select(.health != \"up\")] | length == 0'",
                timeout=180,
            )
            jobs = machine.succeed(
                "curl -fsS 'http://127.0.0.1:9090/api/v1/targets?state=active' "
                "| jq -r '[.data.activeTargets[].labels.job] | sort | join(\",\")'"
            ).strip()
            # smartctl is absent by design on this node — see the comment on
            # observabilityTestNode.
            assert jobs == "alloy,grafana,loki,node,prometheus", jobs

            # Grafana: the sops-decrypted password is what the instance actually
            # accepts, and both datasources were provisioned from Nix.
            machine.succeed("test -e /run/secrets/grafana-admin-password")
            machine.succeed("test -e /run/secrets/grafana-secret-key")

            # Credentials are read out of the decrypted file rather than written
            # into the test, which is both a stronger assertion — it proves the
            # file's *contents* are what Grafana accepts, not just that some
            # known string works — and keeps a `curl -u user:literal` out of the
            # tree, which the gitleaks check flags on sight.
            machine.fail("curl -fsS -u admin:not-the-password http://127.0.0.1:3030/api/datasources")
            types = machine.succeed(
                "PW=$(cat /run/secrets/grafana-admin-password); "
                'curl -fsS -u "admin:$PW" http://127.0.0.1:3030/api/datasources '
                "| jq -r '[.[].type] | sort | join(\",\")'"
            ).strip()
            assert types == "loki,prometheus", types

            # Loki accepts a push and serves it back: a real round trip through
            # the on-pool store, not just a liveness probe.
            machine.wait_until_succeeds("curl -fsS http://127.0.0.1:3100/ready")
            ts = machine.succeed("date +%s%N").strip()
            body = (
                '{"streams":[{"stream":{"job":"nixos-test"},"values":[["'
                + ts
                + '","round-trip-canary"]]}]}'
            )
            machine.succeed(
                "curl -fsS -XPOST -H 'Content-Type: application/json' "
                "http://127.0.0.1:3100/loki/api/v1/push --data-raw '" + body + "'"
            )
            machine.wait_until_succeeds(
                "curl -fsS -G http://127.0.0.1:3100/loki/api/v1/query_range "
                "--data-urlencode 'query={job=\"nixos-test\"}' "
                "| jq -e '.data.result[0].values[0][1] == \"round-trip-canary\"'",
                timeout=60,
            )

            # Alloy ships the journal, and the relabel rules promote the syslog
            # identifier to a real label — without them every line would land in
            # one unfilterable stream, so querying by it proves both halves.
            machine.succeed("systemd-cat -t alloy-canary echo journal-shipping-works")
            machine.wait_until_succeeds(
                "curl -fsS -G http://127.0.0.1:3100/loki/api/v1/query_range "
                "--data-urlencode 'query={syslog_identifier=\"alloy-canary\"}' "
                "| jq -e '.data.result | length > 0'",
                timeout=180,
            )
          '';
        };

        # PostgreSQL: the cluster comes up on the pinned major, is reachable over
        # the Unix socket and *only* the socket, peer auth actually rejects a
        # mismatched system user, and the nightly pg_dumpall produces a real dump.
        test-postgresql = testLib.makeTest {
          name = "postgresql";
          nodes.machine = postgresqlTestNode;
          testScript = ''
            machine.wait_for_unit("postgresql.service")

            # The socket is the only way in, and it works.
            machine.succeed("test -S /run/postgresql/.s.PGSQL.5432")
            machine.succeed("sudo -u postgres psql -tAc 'SELECT 1' | grep -qx 1")

            # No TCP listener at all — the runtime half of the listen_addresses
            # assertion. With `enableTCPIP = false` alone (upstream's default,
            # listen_addresses = "localhost") this line would find :5432 bound on
            # loopback and the test would fail, which is the point of asserting it
            # here rather than trusting the option name.
            machine.fail("ss -ltn | grep -q ':5432'")

            # The pinned major is what actually booted. The eval assertion checks
            # the package; this checks the server that came out of it.
            ver = machine.succeed("sudo -u postgres psql -tAc 'SHOW server_version'").strip()
            assert ver.startswith("18"), "unexpected server_version: " + ver

            # dataDir follows the pinned major, so the cluster is where the
            # SSD-split assertion says it is.
            machine.succeed("test -d /var/lib/postgresql/18")

            # Peer auth bites: a system user with no matching role cannot connect,
            # which is what makes a passwordless socket-only server safe.
            machine.fail("su nobody -s /bin/sh -c 'psql -U postgres -c \"SELECT 1\"'")

            # The dump path, run for real rather than waiting for the timer:
            # pg_dumpall piped through zstd, landing a non-empty file.
            machine.succeed("systemctl start postgresqlBackup.service")
            machine.succeed("test -s /var/lib/postgresql-dump/all.sql.zstd")
            # And it is a genuine cluster dump, not an empty stream that happens
            # to compress to a few bytes.
            machine.succeed(
                "zstd -dc /var/lib/postgresql-dump/all.sql.zstd "
                "| grep -q 'PostgreSQL database cluster dump'"
            )

            # The timer is what makes it nightly; the unit alone would never run.
            machine.succeed("systemctl list-timers --all | grep -q postgresqlBackup")
          '';
        };

        # Virtualisation: libvirtd up, maudi reaches qemu:///system via group
        # socket access, default NAT network defined+autostarting, clients
        # installed. Starting a guest needs nested KVM and is left to manual testing.
        test-virtualisation = testLib.makeTest {
          name = "virtualisation";
          nodes.machine = testNode;
          testScript = ''
            machine.wait_for_unit("multi-user.target")
            machine.wait_for_unit("libvirtd.service")

            # maudi is in the libvirtd group, so qemu:///system is reachable
            # without root (the system socket is group-rw to libvirtd).
            machine.succeed("id maudi | grep -q libvirtd")
            machine.succeed("su maudi -c 'virsh -c qemu:///system list'")

            # The default NAT network is defined and set to autostart.
            machine.wait_for_unit("libvirt-default-network.service")
            machine.succeed("virsh net-list --all | grep -q default")
            machine.succeed("virsh net-info default | grep -qi 'Autostart:.*yes'")

            # virt-manager GUI + virt-viewer console client are installed.
            machine.succeed("test -x /run/current-system/sw/bin/virt-manager")
            machine.succeed("test -x /run/current-system/sw/bin/virt-viewer")
          '';
        };

        # Waydroid: assert the CLI, the waydroid-container service unit, and the
        # Hyprland window rules landed. A full Android session needs binder + KVM
        # and an imperative image download, so it's left to manual testing.
        test-waydroid = testLib.makeTest {
          name = "waydroid";
          nodes.machine = testNode;
          testScript = ''
            machine.wait_for_unit("multi-user.target")

            # The waydroid CLI is on PATH and its container service unit is
            # defined (not necessarily active without binder/KVM).
            machine.succeed("test -x /run/current-system/sw/bin/waydroid")
            machine.succeed("systemctl cat waydroid-container.service")

            # Hyprland integration: the opt-in window rules for the Android
            # toplevels were merged into maudi's rendered hyprland.lua. They are
            # hl.window_rule calls now, so each assertion matches a whole
            # `hl.window_rule({ … })` call (multiline grep, scoped by [^)]*).
            machine.wait_for_unit("home-manager-maudi.service")
            machine.succeed(
                r"grep -Pzoq 'hl\.window_rule\(\{[^)]*class = \"\^\(waydroid\.\*\)\$\"[^)]*float = true' "
                "/home/maudi/.config/hypr/hyprland.lua"
            )
            machine.succeed(
                r"grep -Pzoq 'hl\.window_rule\(\{[^)]*title = \"\^\(Waydroid\)\$\"[^)]*float = true' "
                "/home/maudi/.config/hypr/hyprland.lua"
            )
            machine.succeed(
                r"grep -Pzoq 'hl\.window_rule\(\{[^)]*class = \"\^\(waydroid\.\*\)\$\"[^)]*idle_inhibit = \"focus\"' "
                "/home/maudi/.config/hypr/hyprland.lua"
            )
          '';
        };

        # Gaming stack (desktop only): boot on the CachyOS kernel and assert the
        # sched-ext scheduler is live and the Steam/GPU/overlay pieces installed.
        # Launching a real game / GPU control needs hardware (manual testing).
        test-gaming = testLib.makeTest {
          name = "gaming";
          nodes.machine = gamingTestNode;
          testScript = ''
            machine.wait_for_unit("multi-user.target")

            # Running the CachyOS kernel (uname -r is e.g. "7.0.12-cachyos").
            machine.succeed("uname -r | grep -q cachyos")

            # sched-ext: the scx service is active and configured for scx_lavd.
            # The scheduler is selected via the SCX_SCHEDULER env var (ExecStart
            # just execs "$SCX_SCHEDULER"), so assert on Environment, not ExecStart.
            machine.wait_for_unit("scx.service")
            machine.succeed("systemctl show -p Environment scx.service | grep -q SCX_SCHEDULER=scx_lavd")

            # Steam + companions are installed (steam pulls 32-bit libs).
            machine.succeed("test -x /run/current-system/sw/bin/steam")
            machine.succeed("test -x /run/current-system/sw/bin/gamescope")
            machine.succeed("test -x /run/current-system/sw/bin/gamemoderun")

            # gamemode is this host's performance mode (PPD has no driver on a
            # CPU without CPPC/EPP), so its config must actually raise the
            # governor and the AMD perf level.
            machine.succeed("grep -q '^desiredgov=performance$' /etc/gamemode.ini")
            machine.succeed("grep -q '^amd_performance_level=high$' /etc/gamemode.ini")
            # Raising the governor needs root; the module routes it via pkexec.
            machine.succeed("test -u /run/wrappers/bin/pkexec")

            # 32-bit graphics support is wired (Steam/Proton need it): NixOS
            # exposes the 32-bit driver tree at /run/opengl-driver-32.
            machine.succeed("test -e /run/opengl-driver-32")

            # LACT GPU control tool is installed (lactd needs a real GPU to
            # stay up, so assert the binary, not the unit, in a headless VM).
            machine.succeed("test -x /run/current-system/sw/bin/lact")

            # MangoHud overlay landed in maudi's home profile.
            machine.succeed("test -x /etc/profiles/per-user/maudi/bin/mangohud")
          '';
        };

        # Secrets: prove sops-nix decrypts at activation time. The VM's host key
        # is not a fixture recipient, so force it off and inject a known test age
        # identity (its private half only decrypts secrets/fixtures/test.yaml).
        # Asserts the secret lands in /run/secrets with the right owner/mode and
        # that the plaintext is absent from the store.
        test-secrets = testLib.makeTest {
          name = "secrets";
          nodes.machine = {
            imports = [
              home-manager.nixosModules.home-manager
              inputs.stylix.nixosModules.stylix
              inputs.sops-nix.nixosModules.sops
              ./hosts/private-laptop/default.nix
            ];
            _module.args.inputs = inputs;
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs; };
            };

            environment.etc."test-age-key.txt" = {
              text = testAgeKey + "\n";
              mode = "0400";
            };

            sops = {
              # Override the production key source: the VM's fresh host key is
              # not a fixture recipient. Use the injected test identity.
              age = {
                sshKeyPaths = lib.mkForce [ ];
                keyFile = "/etc/test-age-key.txt";
              };
              gnupg.sshKeyPaths = lib.mkForce [ ];

              # Two secrets from the same fixture key: one root-owned, one
              # user-owned, both 0400 so neither is world-readable.
              secrets = {
                fixture_secret = {
                  sopsFile = ./secrets/fixtures/test.yaml;
                  owner = "root";
                  mode = "0400";
                };
                fixture_user_secret = {
                  sopsFile = ./secrets/fixtures/test.yaml;
                  key = "fixture_secret";
                  owner = "maudi";
                  mode = "0400";
                };
              };
            };
          };
          testScript = ''
            machine.wait_for_unit("multi-user.target")

            # Both secrets materialized at the canonical /run/secrets path and
            # decrypt to the known sentinel.
            machine.succeed("test -e /run/secrets/fixture_secret")
            machine.succeed("grep -q 'sops-fixture-canary-7a3f' /run/secrets/fixture_secret")
            machine.succeed("grep -q 'sops-fixture-canary-7a3f' /run/secrets/fixture_user_secret")

            # Correct owner + mode (0400), so not world-readable.
            machine.succeed("stat -c '%U %a' /run/secrets/fixture_secret | grep -qx 'root 400'")
            machine.succeed("stat -c '%U %a' /run/secrets/fixture_user_secret | grep -qx 'maudi 400'")

            # A non-owner, non-root user cannot read it (root bypasses mode, so
            # assert via an unprivileged read attempt).
            machine.fail("su nobody -s /bin/sh -c 'cat /run/secrets/fixture_secret'")

            # Encrypted at rest: the only copy of the secret that lands in the
            # store is the sops fixture, and it must be ciphertext — the
            # plaintext sentinel must not appear in it. (We can't `grep -r` all
            # of /nix/store: a nixosTest shares the host store with the guest,
            # and the test-driver script itself contains this sentinel.)
            machine.fail("grep -q 'sops-fixture-canary-7a3f' ${./secrets/fixtures/test.yaml}")

            # Decrypted only onto tmpfs at activation: the secret resolves
            # under /run (sops-nix's tmpfs), never to a persistent store path.
            machine.succeed("readlink -f /run/secrets/fixture_secret | grep -q '^/run/'")
          '';
        };
      };

      nixosConfigurations = hosts;

      # devShell templates for `nix flake init -t ~/desktop-nix#<lang>`. Each
      # drops a flake.nix + .envrc (`use flake`) so direnv loads the toolchain.
      templates = {
        rust = {
          path = ./templates/rust;
          description = "Rust devShell (cargo, clippy, nextest, bacon, rust-analyzer)";
        };
        go = {
          path = ./templates/go;
          description = "Go devShell (go, gopls, gotools, gofumpt)";
        };
        node = {
          path = ./templates/node;
          description = "Node devShell (nodejs LTS + typescript-language-server)";
        };
        python = {
          path = ./templates/python;
          description = "Python devShell (python3, uv, ruff, python-lsp-server)";
        };
      };
    };
}
