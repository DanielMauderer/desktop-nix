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
          modules = [ ./hosts/private-laptop/default.nix ];
        };
        work-laptop = mkHost {
          hostname = "work-laptop";
          modules = [ ./hosts/work-laptop/default.nix ];
        };
        desktop = mkHost {
          hostname = "desktop";
          modules = [ ./hosts/desktop/default.nix ];
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
          ./hosts/private-laptop/default.nix
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
