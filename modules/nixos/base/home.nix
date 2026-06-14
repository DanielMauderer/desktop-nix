# Wire the per-user shell & CLI environment (fish, kitty, fastfetch, lazygit,
# CLI tools), neovim and the dev environment (toolchains, cargo extras, direnv,
# Claude config) into the home-manager instance mkHost set up. This lives in
# base because all three are shared by every machine (Tickets 06, 07 & 08,
# Machines: all). Username is `maudi` on every machine (DECISIONS 007).
_: {
  home-manager.users.maudi.imports = [
    ../../home/cli
    ../../home/neovim
    ../../home/dev
  ];
}
