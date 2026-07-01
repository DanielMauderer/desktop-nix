# Pure-Nix unit tests for lib/mkHost.nix.
#
# `nixpkgs.lib.nixosSystem` is mocked to the identity function so these
# assertions inspect exactly the arguments mkHost builds (the module list,
# specialArgs and system string) without evaluating a real NixOS
# configuration. Wired into flake.nix as the `unit-mkhost-check` check via
# `mkUnitCheck`, matching the {name, assertion} list contract already used by
# `mkHostCheck` for the per-host eval assertions.
{ lib }:
let
  mockInputs = {
    stylix.nixosModules.stylix = "MOCK_STYLIX_MODULE";
    sops-nix.nixosModules.sops = "MOCK_SOPS_MODULE";
    disko.nixosModules.disko = "MOCK_DISKO_MODULE";
  };

  # Identity: capture exactly what mkHost passes to nixosSystem instead of
  # building a real NixOS configuration.
  mockNixpkgs = {
    lib.nixosSystem = args: args;
  };

  mockHomeManager = {
    nixosModules.home-manager = "MOCK_HOME_MANAGER_MODULE";
  };

  mockChaotic = {
    nixosModules.default = "MOCK_CHAOTIC_MODULE";
  };

  mkHost = import ./mkHost.nix {
    inputs = mockInputs;
    nixpkgs = mockNixpkgs;
    home-manager = mockHomeManager;
    chaotic = mockChaotic;
  };

  userModule = {
    testMarker = "user-module";
  };

  basic = mkHost {
    hostname = "test-host";
    modules = [ userModule ];
  };

  withChaotic = mkHost {
    hostname = "gaming-host";
    modules = [ userModule ];
    withChaotic = true;
  };

  customSystem = mkHost {
    hostname = "arm-host";
    modules = [ ];
    system = "aarch64-linux";
  };

  homeManagerModule = lib.findFirst (m: builtins.isAttrs m && m ? home-manager) null basic.modules;
in
[
  {
    name = "defaults to x86_64-linux when system is not given";
    assertion = basic.system == "x86_64-linux";
  }
  {
    name = "honours an explicit system argument";
    assertion = customSystem.system == "aarch64-linux";
  }
  {
    name = "specialArgs carries the hostname through";
    assertion = basic.specialArgs.hostname == "test-host";
  }
  {
    name = "specialArgs carries the flake inputs through";
    assertion = basic.specialArgs.inputs == mockInputs;
  }
  {
    name = "home-manager NixOS module is present";
    assertion = builtins.elem "MOCK_HOME_MANAGER_MODULE" basic.modules;
  }
  {
    name = "stylix NixOS module is present";
    assertion = builtins.elem "MOCK_STYLIX_MODULE" basic.modules;
  }
  {
    name = "sops-nix NixOS module is present";
    assertion = builtins.elem "MOCK_SOPS_MODULE" basic.modules;
  }
  {
    name = "disko NixOS module is present";
    assertion = builtins.elem "MOCK_DISKO_MODULE" basic.modules;
  }
  {
    name = "chaotic module is absent unless withChaotic = true";
    assertion = !(builtins.elem "MOCK_CHAOTIC_MODULE" basic.modules);
  }
  {
    name = "chaotic module is added when withChaotic = true";
    assertion = builtins.elem "MOCK_CHAOTIC_MODULE" withChaotic.modules;
  }
  {
    name = "caller-supplied modules are appended, in order, after the built-ins";
    assertion = lib.last basic.modules == userModule;
  }
  {
    name = "a home-manager config block is present in the module list";
    assertion = homeManagerModule != null;
  }
  {
    name = "home-manager.useGlobalPkgs is enabled";
    assertion = homeManagerModule.home-manager.useGlobalPkgs == true;
  }
  {
    name = "home-manager.useUserPackages is enabled";
    assertion = homeManagerModule.home-manager.useUserPackages == true;
  }
  {
    name = "home-manager.extraSpecialArgs threads the flake inputs to home-manager modules";
    assertion = homeManagerModule.home-manager.extraSpecialArgs == {
      inputs = mockInputs;
    };
  }
]