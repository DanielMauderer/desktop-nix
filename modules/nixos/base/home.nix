# Wire the per-user shell & CLI environment (fish, kitty, fastfetch, lazygit,
# CLI tools) into the home-manager instance mkHost set up. This lives in base
# because the shell environment is shared by every machine (Ticket 06,
# Machines: all). Username is `maudi` on every machine (DECISIONS 007).
_: {
  home-manager.users.maudi.imports = [ ../../home/cli ];
}
