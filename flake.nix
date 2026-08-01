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
