_: {
  networking.networkmanager.enable = true;

  # IPv6 interface IDs derived from the MAC (EUI-64) instead of NetworkManager's
  # default `stable-privacy` (RFC 7217). Stable-privacy hashes the *prefix* into
  # the interface ID, so a host on a dynamic-prefix line gets a brand new address
  # tail every time the ISP rotates the prefix. That breaks anything pinned to the
  # tail — notably the FRITZ!Box "IPv6 Interface-ID" of an exposed host, which has
  # to be entered by hand. With EUI-64 the tail is constant across prefix changes
  # (it only moves if the NIC is replaced).
  #
  # Complements `networking.tempAddresses = "disabled"` in server/cloudflare-ddns.nix:
  # that picks the stable SLAAC address over rotating temporary ones, this pins what
  # that stable address looks like.
  networking.networkmanager.settings.connection."ipv6.addr-gen-mode" = "eui64";
}
