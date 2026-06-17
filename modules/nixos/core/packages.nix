# Minimal system-wide package set. User-facing CLI tools (bat, fd, ripgrep,
# fzf, tree, btop, …) live in home-manager (Ticket 06); base keeps only what
# the system itself needs for recovery, flakes and VPN.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    wireguard-tools
    pciutils
    usbutils
  ];
}
