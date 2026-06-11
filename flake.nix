{
  description = "Declarative NixOS configuration for private-laptop, work-laptop, and desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      mkHost = import ./lib/mkHost.nix { inherit nixpkgs home-manager; };
      username = "maudi";
    in
    {
      nixosConfigurations = {
        private-laptop = mkHost {
          hostName = "private-laptop";
          inherit system username;
          modules = [ ./hosts/private-laptop ];
        };
        work-laptop = mkHost {
          hostName = "work-laptop";
          inherit system username;
          modules = [ ./hosts/work-laptop ];
        };
        desktop = mkHost {
          hostName = "desktop";
          inherit system username;
          modules = [ ./hosts/desktop ];
        };
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nil
          statix
          deadnix
          nixfmt-rfc-style
        ];
      };
    };
}
