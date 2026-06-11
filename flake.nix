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
      self,
      nixpkgs,
      home-manager,
      chaotic,
      hyprland,
      ...
    }:
    let
      mkHost = import ./lib/mkHost.nix {
        inherit inputs nixpkgs home-manager chaotic;
      };
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;

      devShells.x86_64-linux.default =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.mkShell {
          packages = with pkgs; [
            nil
            statix
            deadnix
            nixfmt-rfc-style
          ];
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
