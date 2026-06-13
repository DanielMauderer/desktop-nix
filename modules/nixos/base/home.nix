# Wire the per-user shell & CLI environment (fish, kitty, fastfetch, lazygit,
# CLI tools) and neovim into the home-manager instance mkHost set up. This
# lives in base because both are shared by every machine (Tickets 06 & 07,
# Machines: all). Username is `maudi` on every machine (DECISIONS 007).
_: {
  home-manager.users.maudi.imports = [
    ../../home/cli
    ../../home/neovim
  ];
}
