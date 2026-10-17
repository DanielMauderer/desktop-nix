_: {
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # CI pushes the Hyprland/Noctalia builds here (ci.yml warm-cache), so
      # autoUpgrade and local rebuilds download them instead of compiling.
      extra-substituters = [ "https://desktop-nix.cachix.org" ];
      extra-trusted-public-keys = [
        "desktop-nix.cachix.org-1:sijjL+d3J1pda/YjMZp/aaEctww8SLjRIHkrQ0lOlMQ="
      ];
      trusted-users = [
        "root"
        "maudi"
      ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    optimise.automatic = true;
  };
}
