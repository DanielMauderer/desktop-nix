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
        inherit inputs nixpkgs home-manager chaotic;
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
        nixfmt-check = pkgs.runCommand "nixfmt-check" {
          nativeBuildInputs = [ pkgs.nixfmt-rfc-style ];
        } ''
          find ${./.} -name "*.nix" | xargs nixfmt --check
          touch $out
        '';

        statix-check = pkgs.runCommand "statix-check" {
          nativeBuildInputs = [ pkgs.statix ];
        } ''
          statix check ${./.}
          touch $out
        '';

        deadnix-check = pkgs.runCommand "deadnix-check" {
          nativeBuildInputs = [ pkgs.deadnix ];
        } ''
          deadnix --fail ${./.}
          touch $out
        '';

        # Template nixosTest: boot private-laptop config, assert multi-user.target.
        # Later tickets copy this pattern (e.g. assert Hyprland unit, libvirtd active).
        test-boot-private-laptop = nixpkgs.lib.nixos.runTest {
          hostPkgs = pkgs;
          name = "boot-private-laptop";
          nodes.machine.imports = [ ./hosts/private-laptop/default.nix ];
          testScript = ''
            machine.wait_for_unit("multi-user.target")
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
