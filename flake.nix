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

    # Theming engine (Ticket 05 / DECISIONS 022): derives one base16 palette
    # from a wallpaper image at build time and themes GTK/Qt/kitty/rofi/waybar/
    # hyprland/swaylock/swaync declaratively.
    stylix = {
      url = "git+https://github.com/nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen Browser (Ticket 10 / DECISIONS 030): community flake, twilight channel
    # for reproducibility (official release artifacts may be deleted by the Zen team).
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    # Secrets (Ticket 12 / DECISIONS 035): sops-nix decrypts secrets at
    # activation time using each host's SSH host ed25519 key (converted to age)
    # plus a personal master age key. Nothing is decrypted at eval time, so
    # keyless CI runners still build every host.
    sops-nix = {
      url = "git+https://github.com/Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning (Ticket 13 / DECISIONS 036): the pilot
    # (private-laptop) is partitioned from a checked-in disko spec so a
    # reinstall reproduces the exact LUKS + ext4 + ESP layout. Imported only by
    # the host that uses it (hosts/private-laptop/disk.nix), not globally.
    disko = {
      url = "git+https://github.com/nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
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
      mkHost = import ./lib/mkHost.nix {
        inherit
          inputs
          nixpkgs
          home-manager
          chaotic
          ;
      };

      hosts = {
        private-laptop = mkHost {
          hostname = "private-laptop";
          # disk.nix carries the disko spec (LUKS + ext4 + ESP) and is added
          # only to the real nixosConfiguration — the nixosTest nodes below
          # import default.nix alone, so the QEMU VMs use their own scratch
          # disk and never the host's LUKS layout.
          modules = [
            ./hosts/private-laptop/default.nix
            ./hosts/private-laptop/disk.nix
          ];
        };
        work-laptop = mkHost {
          hostname = "work-laptop";
          # disk.nix carries the disko LUKS spec and is added only here — not
          # imported by default.nix — so nixosTest VMs use their own scratch disk.
          modules = [
            ./hosts/work-laptop/default.nix
            ./hosts/work-laptop/disk.nix
          ];
        };
        desktop = mkHost {
          hostname = "desktop";
          # disk.nix carries the disko spec (GPT + ESP + plain ext4, no LUKS)
          # and is added only here — not imported by default.nix — so nixosTest
          # VMs use their own scratch disk.
          modules = [
            ./hosts/desktop/default.nix
            ./hosts/desktop/disk.nix
          ];
          withChaotic = true;
        };
      };

      # Eval-time host assertions (DECISIONS 021): facts about the evaluated
      # config are checked while the check derivation is *constructed*, so a
      # failure aborts `nix flake check` naming every failed assertion for the
      # host. extraScript runs at build time against rendered files.
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

      kanshiProfileNames =
        cfg: map (p: p.profile.name) cfg.home-manager.users.maudi.services.kanshi.settings;

      # Assertions shared by every host.
      baseAssertions = host: cfg: [
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
          name = "stylix enabled with a wallpaper (Ticket 05)";
          assertion = cfg.stylix.enable && cfg.stylix.image != null;
        }
        {
          name = "fish managed in home (Ticket 06)";
          assertion = cfg.home-manager.users.maudi.programs.fish.enable;
        }
        {
          name = "starship prompt enabled (Ticket 06)";
          assertion = cfg.home-manager.users.maudi.programs.starship.enable;
        }
        {
          name = "podman enabled with docker compat (Ticket 08)";
          assertion = cfg.virtualisation.podman.enable && cfg.virtualisation.podman.dockerCompat;
        }
        {
          name = "direnv + nix-direnv enabled in home (Ticket 08)";
          assertion =
            cfg.home-manager.users.maudi.programs.direnv.enable
            && cfg.home-manager.users.maudi.programs.direnv.nix-direnv.enable;
        }
        {
          name = "libvirtd enabled with swtpm TPM emulation (Ticket 09)";
          assertion = cfg.virtualisation.libvirtd.enable && cfg.virtualisation.libvirtd.qemu.swtpm.enable;
        }
        {
          name = "virt-manager enabled and maudi in libvirtd group (Ticket 09)";
          assertion =
            cfg.programs.virt-manager.enable && builtins.elem "libvirtd" cfg.users.users.maudi.extraGroups;
        }
        {
          name = "allowUnfreePredicate whitelists spotify (Ticket 10)";
          assertion = cfg.nixpkgs.config.allowUnfreePredicate pkgs.spotify;
        }
        {
          name = "spotify in maudi home.packages (Ticket 10)";
          assertion = builtins.any (
            p: (p.pname or "") == "spotify"
          ) cfg.home-manager.users.maudi.home.packages;
        }
        {
          name = "sops age key derived from host ssh ed25519 key (Ticket 12)";
          assertion = builtins.elem "/etc/ssh/ssh_host_ed25519_key" cfg.sops.age.sshKeyPaths;
        }
        {
          name = "SSH daemon disabled (Ticket 14 / DECISIONS 037)";
          assertion = !cfg.services.openssh.enable;
        }
        {
          name = "root account locked (Ticket 14 / DECISIONS 037)";
          assertion = cfg.users.users.root.hashedPassword == "!";
        }
        {
          name = "firewall enabled (Ticket 14 / DECISIONS 037)";
          assertion = cfg.networking.firewall.enable;
        }
        {
          name = "auditd enabled for security-event logging (policy §4.3/4.5, DECISIONS 039)";
          assertion = cfg.security.auditd.enable && cfg.security.audit.enable;
        }
        {
          name = "security updates applied daily, ≤72h window (policy §4.4, DECISIONS 039)";
          assertion = cfg.system.autoUpgrade.enable && cfg.system.autoUpgrade.dates == "daily";
        }
      ];
      testLib = import "${nixpkgs}/nixos/lib/testing-python.nix" {
        inherit system pkgs;
      };

      # Shared nixosTest node: the private-laptop host plus the home-manager
      # NixOS module and `inputs` that mkHost normally supplies (the host now
      # pulls in modules/nixos/desktop, which configures home-manager and reads
      # the Hyprland flake input).
      testNode = {
        imports = [
          home-manager.nixosModules.home-manager
          inputs.stylix.nixosModules.stylix
          inputs.sops-nix.nixosModules.sops
          ./hosts/private-laptop/default.nix
        ];
        _module.args.inputs = inputs;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
      };

      # Gaming test node (Ticket 11): the desktop host, which mkHost composes
      # with the chaotic module (CachyOS kernel + scx) on top of the same
      # home-manager/stylix/inputs wiring as testNode. The shared testNode can't
      # be reused — it boots private-laptop, which deliberately has no chaotic.
      gamingTestNode = {
        imports = [
          home-manager.nixosModules.home-manager
          inputs.stylix.nixosModules.stylix
          inputs.sops-nix.nixosModules.sops
          chaotic.nixosModules.default
          ./hosts/desktop/default.nix
        ];
        _module.args.inputs = inputs;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
      };
    in
    {
      formatter.${system} = pkgs.nixfmt-rfc-style;

      devShells.${system} = {
        default = pkgs.mkShell {
          packages = with pkgs; [
            nil
            statix
            deadnix
            nixfmt-rfc-style
            # Secrets (Ticket 12): edit/re-key sops files and convert SSH host
            # keys to age for the bootstrap runbook (docs/runbooks/secrets.md).
            sops
            ssh-to-age
            age
          ];
        };

        # Per-language project shells (Ticket 08 / DECISIONS 027). Enter with
        # `nix develop ~/desktop-nix#rust`, or scaffold a project with
        # `nix flake init -t ~/desktop-nix#rust` (drops a flake.nix + .envrc).
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
            nodePackages.typescript-language-server
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

        # Formatting is gated here (not as a separate CI step) so that local
        # `nix flake check` and CI stay identical (Ticket 02: no drift).
        nixfmt-check =
          pkgs.runCommand "nixfmt-check"
            {
              nativeBuildInputs = [ pkgs.nixfmt-rfc-style ];
            }
            ''
              find ${./.} -name '*.nix' -print0 | xargs -0 nixfmt --check
              touch $out
            '';

        # Dev devShell smoke checks (Ticket 08): each toolchain compiles/runs a
        # trivial hello-world offline, so a broken per-language shell fails the
        # flake check. Cheap (node/python/go) plus a minimal rust+nextest build.
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
        # don't assert: chaotic only on desktop, kanshi profile ordering
        # (docked/dual-head profiles must match before the laptop-internal
        # fallback) and the rendered kanshi config the daemon actually reads.
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
                # Gaming stack (Ticket 11) is desktop-only — the Intel laptop
                # must not pull in scx, Steam or 32-bit graphics.
                {
                  name = "no gaming stack (scx + steam disabled)";
                  assertion =
                    !cfg.services.scx.enable && !cfg.programs.steam.enable && !cfg.hardware.graphics.enable32Bit;
                }
                # Waydroid (Ticket 16 / DECISIONS 040) is opt-in on private-laptop.
                {
                  name = "waydroid enabled (Ticket 16)";
                  assertion = cfg.virtualisation.waydroid.enable;
                }
              ]
            )
            ''
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
                # Gaming stack (Ticket 11) is desktop-only.
                {
                  name = "no gaming stack (scx + steam disabled)";
                  assertion =
                    !cfg.services.scx.enable && !cfg.programs.steam.enable && !cfg.hardware.graphics.enable32Bit;
                }
                # Waydroid (Ticket 16 / DECISIONS 040): the Android container is
                # deliberately absent from the work laptop.
                {
                  name = "waydroid NOT enabled (Ticket 16)";
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
                # Gaming stack (Ticket 11), desktop-only.
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
                  name = "MangoHud enabled in maudi's home";
                  assertion = cfg.home-manager.users.maudi.programs.mangohud.enable;
                }
                # Waydroid (Ticket 16 / DECISIONS 040) is opt-in on desktop.
                {
                  name = "waydroid enabled (Ticket 16)";
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
              conf=${kanshiConfig "desktop"}
              grep -q 'output "DP-3" mode 2560x1440@144 position 0,0' "$conf"
              grep -q 'output "DP-2" mode 1920x1080@60 position 2560,0' "$conf"
              test "$(grep '^profile' "$conf" | tail -1)" = 'profile laptop-internal {'
            '';

        # Template nixosTest: boot private-laptop config, assert multi-user.target.
        # Later tickets copy this pattern (e.g. assert Hyprland unit, libvirtd active).
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

            # Shell & CLI environment (Ticket 06): base now wires the cli home
            # module, so the maudi home generation built fish + the tool configs.
            machine.wait_for_unit("home-manager-maudi.service")

            # Configs rendered for fish, kitty, fastfetch and lazygit.
            machine.succeed("test -e /home/maudi/.config/fish/config.fish")
            machine.succeed("test -e /home/maudi/.config/kitty/kitty.conf")
            machine.succeed("test -e /home/maudi/.config/fastfetch/config.jsonc")
            machine.succeed("test -e /home/maudi/.config/lazygit/config.yml")

            # fish starts cleanly and the ported aliases/functions resolve.
            machine.succeed("su maudi -c 'fish -ic \"true\"'")
            machine.succeed("su maudi -c 'fish -ic \"type ls\"' | grep -q eza")
            machine.succeed("su maudi -c 'fish -ic \"type cat\"' | grep -q bat")
            machine.succeed(
                "su maudi -c 'fish -ic \"functions -q mkcd; and functions -q gst\"'"
            )

            # Prompt is declarative starship (no tide / no universal-var setup):
            # the binary is installed and fish's interactive init sources it.
            machine.succeed("test -x /etc/profiles/per-user/maudi/bin/starship")
            machine.succeed("grep -q 'starship init fish' /home/maudi/.config/fish/config.fish")

            # The migrated CLI tools are on maudi's PATH.
            machine.succeed(
                "for b in eza bat fd rg btop zoxide delta tree fzf lazygit fastfetch; do "
                "test -x /etc/profiles/per-user/maudi/bin/$b; done"
            )

            # Hardening (Ticket 14 / DECISIONS 037): SSH daemon must not be running
            # and the firewall must be active.
            machine.fail("systemctl is-active sshd")
            machine.succeed("nft list ruleset | grep -q 'type filter hook input'")

            # Security-event logging (policy §4.3/4.5/4.6, DECISIONS 039): auditd is
            # up with our rules loaded, sudo logs to its dedicated file, and the
            # journal is persistent.
            machine.wait_for_unit("auditd.service")
            # Rules are applied by the audit-rules-nixos.service oneshot at
            # sysinit (before multi-user.target, already reached above). Assert
            # it succeeded and the priv_esc rule is live — `succeed`, not a long
            # `wait_until_succeeds`, so a future rule-load regression fails in
            # seconds instead of timing out after 900s (DECISIONS 041).
            machine.succeed("systemctl is-active audit-rules-nixos.service")
            machine.succeed("auditctl -l | grep -q priv_esc")
            machine.succeed("grep -q 'logfile=/var/log/sudo.log' /etc/sudoers")
            # Storage=persistent makes journald keep logs under /var/log/journal.
            machine.succeed("test -d /var/log/journal")
          '';
        };

        # Desktop stack (Ticket 04): the host now imports modules/nixos/desktop,
        # so booting it exercises the Hyprland session registration, greeter,
        # polkit agent and the maudi home-manager generation (waybar, swaylock).
        test-desktop = testLib.makeTest {
          name = "desktop";
          nodes.machine = testNode;
          testScript = ''
            machine.wait_for_unit("multi-user.target")

            # Greeter is up and the Hyprland session binary is installed.
            machine.wait_for_unit("greetd.service")
            machine.succeed("test -x /run/current-system/sw/bin/Hyprland")

            # Power-profile backend for the waybar module. It is D-Bus
            # activated (inactive at boot), so verify it is installed and
            # actually starts rather than waiting for it.
            machine.succeed("systemctl start power-profiles-daemon.service")

            # maudi's home generation built the user desktop: the bar, the lock
            # binary and the polkit agent unit are all present in the profile.
            machine.succeed("test -x /etc/profiles/per-user/maudi/bin/waybar")
            machine.succeed("test -x /etc/profiles/per-user/maudi/bin/swaylock")
            machine.succeed(
                "test -e /etc/profiles/per-user/maudi/share/systemd/user/hyprpolkitagent.service"
            )

            # The Hyprland user config was rendered by home-manager.
            machine.wait_for_unit("home-manager-maudi.service")
            machine.succeed("test -e /home/maudi/.config/hypr/hyprland.conf")

            # kanshi: config rendered, service wired to hyprland-session.target.
            machine.succeed("test -e /home/maudi/.config/kanshi/config")
            machine.succeed("grep -q 'profile laptop-internal' /home/maudi/.config/kanshi/config")
            machine.succeed(
                "test -e /home/maudi/.config/systemd/user/hyprland-session.target.wants/kanshi.service"
            )

            # swaync: notification daemon unit installed and config rendered
            # (replaces dunst — DECISIONS 022).
            machine.succeed("test -e /home/maudi/.config/systemd/user/swaync.service")
            machine.succeed("test -e /home/maudi/.config/swaync/config.json")

            # stylix theming reached the user config: the waybar palette block
            # is prepended from the base16 colours, and swaync got a stylix style.
            machine.succeed("grep -q '@define-color base ' /home/maudi/.config/waybar/style.css")
            machine.succeed("test -e /home/maudi/.config/swaync/style.css")

            # swayidle: wanted by graphical-session.target, locks via swaylock.
            machine.succeed(
                "test -e /home/maudi/.config/systemd/user/graphical-session.target.wants/swayidle.service"
            )
            machine.succeed("grep -q swaylock /home/maudi/.config/systemd/user/swayidle.service")

            # rofi launcher config + ported rasi theme (referenced from
            # config.rasi via @theme, generated with the stylix palette);
            # wlogout; swaylock config.
            machine.succeed("test -e /home/maudi/.config/rofi/config.rasi")
            machine.succeed("grep -q '@theme' /home/maudi/.config/rofi/config.rasi")
            machine.succeed("test -e /home/maudi/.config/wlogout/layout")
            machine.succeed("test -e /home/maudi/.config/wlogout/style.css")
            machine.succeed("test -e /home/maudi/.config/swaylock/config")

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

        # Dev containers (Ticket 08): the dev system module is imported by base,
        # so booting any host gives podman. Run a container from a store-loaded
        # image (the VM has no network) and verify the docker→podman compat shim
        # and podman-compose are present.
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

        # Virtualisation (Ticket 09): the libvirt module is imported by base, so
        # booting any host gives libvirtd. Assert the daemon is up, maudi reaches
        # qemu:///system via libvirtd-group socket access, the default NAT network
        # is defined+autostarting, and the GUI/console clients are installed.
        # Starting an actual guest needs nested KVM and is left to manual testing.
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

        # Waydroid (Ticket 16, private-laptop + desktop): the shared testNode
        # boots private-laptop, which imports modules/nixos/waydroid. Assert the
        # CLI and the waydroid-container service unit are installed and the
        # Hyprland window rules landed. A full Android session needs binder +
        # KVM and an imperative `waydroid init` image download, so starting the
        # container is left to manual on-hardware testing (Ticket 16 checklist).
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
            # toplevels were merged into maudi's rendered hyprland.conf.
            machine.wait_for_unit("home-manager-maudi.service")
            machine.succeed(
                "grep -q 'windowrule=float, class:\\^(waydroid.*)\\$' "
                "/home/maudi/.config/hypr/hyprland.conf"
            )
            machine.succeed(
                "grep -q 'windowrule=float, title:\\^(Waydroid)\\$' "
                "/home/maudi/.config/hypr/hyprland.conf"
            )
            machine.succeed(
                "grep -q 'windowrule=idleinhibit focus, class:\\^(waydroid.*)\\$' "
                "/home/maudi/.config/hypr/hyprland.conf"
            )
          '';
        };

        # Gaming stack (Ticket 11, desktop only): boot the desktop host on the
        # CachyOS kernel and assert the sched-ext scheduler is live and the
        # Steam/GPU/overlay pieces are installed. The kernel + steam closure are
        # pulled from the chaotic cache (CI extra-conf), not built. Launching a
        # real game / GPU control needs hardware and is left to manual testing.
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

        # Secrets (Ticket 12): prove sops-nix decrypts at *activation* time. The
        # production key source is each host's SSH host key, but the VM's host
        # key is not a recipient of the fixture — so this node forces it off and
        # injects a known test age identity instead (its private half guards
        # nothing real: it only decrypts secrets/fixtures/test.yaml). Asserts the
        # secret lands in /run/secrets with the right owner/mode, is not
        # world-readable, and that the plaintext is absent from the nix store
        # (encrypted-at-rest). Keyless CI host builds are the negative test that
        # this is activation-time, not eval-time.
        test-secrets =
          let
            testAgeKey = "AGE-SECRET-KEY-1ZTVVG7CHXYCL2JLJ6ADJ3JDMQ32AQPEWHHYNZ3E9MVM7KA6QZQFQC2JGGK";
          in
          testLib.makeTest {
            name = "secrets";
            nodes.machine = {
              imports = [
                home-manager.nixosModules.home-manager
                inputs.stylix.nixosModules.stylix
                inputs.sops-nix.nixosModules.sops
                ./hosts/private-laptop/default.nix
              ];
              _module.args.inputs = inputs;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

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

                # Two secrets from the same fixture key: one root-owned (the
                # wireguard case, Ticket 14) and one user-owned (the token case),
                # both 0400 so neither is world-readable.
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

      # devShell templates for `nix flake init -t ~/desktop-nix#<lang>`
      # (Ticket 08 / DECISIONS 027). Each drops a flake.nix + .envrc (`use flake`)
      # so direnv loads the toolchain on `cd`.
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
