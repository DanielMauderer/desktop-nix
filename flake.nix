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
      mkHost = import ./lib/mkHost.nix {
        inherit
          inputs
          nixpkgs
          home-manager
          chaotic
          ;
      };
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
          ./hosts/private-laptop/default.nix
        ];
        _module.args.inputs = inputs;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
      };
    in
    {
      formatter.${system} = pkgs.nixfmt-rfc-style;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nil
          statix
          deadnix
          nixfmt-rfc-style
        ];
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
            machine.succeed("test -e /home/maudi/.config/hypr/hyprland.conf")
          '';
        };
      };

      nixosConfigurations = {
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
    };
}
