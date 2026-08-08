# A fixed IPv6 interface ID for the LAN link.
#
# The FRITZ!Box can only forward inbound IPv6 to this host as an "exposed host",
# and that entry is pinned to a hand-entered *IPv6 Interface-ID* — the low 64 bits
# of the address. NetworkManager's default addressing is `stable-privacy`
# (RFC 7217), which hashes the /64 prefix into the interface ID. The ISP rotates
# the prefix nightly, so the interface ID rotated with it and the exposed-host
# entry pointed at an address nobody had: inbound traffic died every night.
#
# `ipv6.token` pins the interface ID to a constant, so only the prefix moves. The
# value below is what the FRITZ!Box has stored; changing it here means editing it
# there too. NetworkManager rejects `token` unless `addr-gen-mode` is explicitly
# `eui64` — plain EUI-64 would also be prefix-independent, but it is derived from
# the NIC's MAC, so replacing the board would silently break the router entry.
#
# Written to /etc as a keyfile rather than via `networking.networkmanager
# .ensureProfiles`: that option's unit runs *after* NetworkManager.service, by
# which time NM has already auto-generated its own "Wired connection 1" for the
# link and brought it up with a stable-privacy address. A keyfile in
# /etc/NetworkManager/system-connections exists before NM starts, so NM has a
# matching profile on its first pass and never creates the auto-default.
#
# This is the only NetworkManager profile the host needs; it is a headless box on
# a single wired link. wg0 is configured by server/wireguard.nix, not by NM.
{
  environment.etc."NetworkManager/system-connections/lan.nmconnection" = {
    # A real file, not the usual /nix/store symlink: NetworkManager refuses to
    # load keyfiles it considers world-readable.
    mode = "0600";
    text = ''
      [connection]
      id=lan
      uuid=cd0f1679-9b99-4a34-b8bd-3ed6c7f4c5a7
      type=ethernet
      interface-name=enp5s0
      autoconnect=true

      [ipv4]
      method=auto

      [ipv6]
      method=auto
      addr-gen-mode=eui64
      token=::23cf:ab78:2ef0:2176
    '';
  };
}
