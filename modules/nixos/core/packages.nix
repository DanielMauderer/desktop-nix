# Minimal system-wide set; user-facing CLI tools live in home-manager.
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
