# Internal DNS: native `services.blocky` — a caching, filtering DNS proxy that
# blocks ads/trackers network-wide and answers the local names no public resolver
# knows about. It is the LAN's resolver; every client that takes its address from
# the FRITZ!Box ends up here (see the "Internal DNS" section of INSTALL.md).
#
# Why blocky and not Pi-hole / AdGuard Home / Technitium: all four block ads, but
# only blocky is configured *entirely* from this file. The other three keep their
# real configuration in a mutable database behind a web UI, so the Nix code would
# stop being the source of truth for how the network resolves — and Pi-hole would
# additionally be a container with its own state directory. Blocky is a single Go
# binary reading one generated YAML file, with `blocky validate` run at build time
# by the NixOS module (`enableConfigCheck`), so a broken resolver config fails
# `nix flake check` instead of the LAN.
#
# Exposure (no new WAN ports; the WAN surface stays UDP 51820 + TCP 80/443):
#   53    DNS (UDP + TCP) on the loopback, LAN and VPN addresses — never a
#         wildcard bind, see the note on `ports.dns`. An open resolver reachable
#         from the WAN is a DNS amplification reflector, so — as in nfs.nix and
#         forgejo.nix — the port is admitted by source-restricted nftables rules
#         and never enters `allowedUDPPorts` / `allowedTCPPorts`.
#   4001  blocky's REST API, bound to 127.0.0.1 and therefore reachable only from
#         the box itself (i.e. over VPN-only SSH). It is what the `blocky` CLI
#         talks to; :4000 is taken by Forgejo.
#
# Upstream privacy: queries that are not blocked or answered locally leave over
# DNS-over-TLS to Cloudflare and Quad9, so the ISP sees TLS to two hosts instead
# of every name this house looks up. `bootstrapDns` carries those two resolvers'
# IPs, which is what keeps that from being circular.
#
# The blocklists are fetched at runtime and cached under the unit's
# StateDirectory (see `loading.downloads.cachePath`), never into the Nix store.
# That keeps a multi-megabyte moving target out of the flake and lets a refresh
# happen without a rebuild, at the cost of the lists being the one part of this
# file that is not pinned.
{ config, lib, ... }:
let
  # EDIT to match your network. Same LAN as nfs.nix/forgejo.nix, same VPN subnet
  # as wireguard.nix.
  lanSubnet = "192.168.178.0/24";
  vpnSubnet = "10.100.0.0/24";

  # The router: it is the DHCP server, so it — not blocky — knows the names of
  # the LAN's clients. `conditional` below hands those lookups back to it.
  router = "192.168.178.1";

  # This box's LAN address. Must be the DHCP reservation from INSTALL.md: it is
  # both what clients are told to resolve against and what the split-horizon
  # answers below point at.
  serverLanAddress = "192.168.178.96";

  # Its wg0 address, from wireguard.nix — the only address a roaming VPN client
  # can reach, since those tunnels route just 10.100.0.0/24.
  serverVpnAddress = "10.100.0.1";

  dnsPort = 53;
  apiPort = 4001;

  # `StateDirectory = "blocky"` in the upstream unit; the only writable path the
  # service has (it runs DynamicUser under ProtectSystem = strict).
  stateDir = "/var/lib/blocky";
in
{
  services.blocky = {
    enable = true;

    settings = {
      ports = {
        # Named addresses, never the `53` wildcard, and this is load-bearing:
        # podman's aardvark-dns binds :53 on the gateway of every DNS-enabled
        # container network (10.88.0.1 for the default bridge, 10.89.x.1 for each
        # compose project). A wildcard bind takes those addresses too, and then
        # whichever of the two starts second dies with EADDRINUSE — in practice
        # blocky wins the boot race and every container network fails to come up.
        # Listing addresses keeps the bridges out of blocky's hands.
        dns = lib.concatMapStringsSep "," (addr: "${addr}:${toString dnsPort}") [
          "127.0.0.1"
          serverLanAddress
          serverVpnAddress
        ];
        # Both of those are late: the LAN address arrives with the DHCP lease and
        # the VPN address with wireguard-wg0.service. IP_FREEBIND lets blocky
        # bind them before they exist, so the resolver does not have to be
        # ordered after the network — a resolver that waits for the network is a
        # resolver that is down every time something upstream of it is slow.
        freeBind = true;
        # Loopback only. The API can disable blocking and dump query stats, and
        # it has no authentication of its own, so it gets no listener beyond the
        # box itself — SSH (VPN-only) is the access path.
        http = "127.0.0.1:${toString apiPort}";
      };

      upstreams = {
        groups.default = [
          "tcp-tls:one.one.one.one:853"
          "tcp-tls:dns.quad9.net:853"
        ];
        # Ask both and take the faster answer; a resolver going down costs
        # latency, not resolution.
        strategy = "parallel_best";
        # Do not block startup on reaching the upstreams. The box boots before
        # (and sometimes without) the WAN link, and a resolver that refuses to
        # start is a LAN-wide outage — with `fast` it serves cache, local names
        # and blocklists immediately and picks the upstreams up when they answer.
        init.strategy = "fast";
      };

      # The upstreams above are named, not numbered, so blocky needs somewhere to
      # resolve those two names before it has a resolver: these are their own
      # addresses, spoken to directly.
      bootstrapDns = [
        {
          upstream = "tcp-tls:one.one.one.one:853";
          ips = [
            "1.1.1.1"
            "1.0.0.1"
          ];
        }
        {
          upstream = "tcp-tls:dns.quad9.net:853";
          ips = [
            "9.9.9.9"
            "149.112.112.112"
          ];
        }
      ];

      blocking = {
        # Two complementary lists rather than a pile of overlapping ones:
        # HaGeZi Pro is the ad/tracker/telemetry list, TIF Medium is threat
        # intelligence (malware, phishing, scam domains). Both are the *wildcard*
        # flavour, which is the format HaGeZi publishes for blocky specifically.
        denylists = {
          ads = [ "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/pro.txt" ];
          threats = [
            "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/tif.medium.txt"
          ];
        };

        # Exceptions, applied on top of the denylists. An inline list, so an
        # over-blocked domain is unblocked by a commit here rather than by
        # clicking in a UI. It must stay attached to a group that also has a
        # denylist: a group with *only* an allowlist means "block everything
        # else" in blocky.
        allowlists.ads = [
          ''
            # One entry per line. `*.example.com` covers the domain and its
            # subdomains; a bare `example.com` matches that name and nothing else.
          ''
        ];

        clientGroupsBlock.default = [
          "ads"
          "threats"
        ];

        # 0.0.0.0 / :: rather than NXDOMAIN: clients fail fast and visibly
        # instead of retrying, and it does not look like a broken zone.
        blockType = "zeroIP";
        # Short, so that an allowlist change or `blocky blocking disable` takes
        # effect in a minute instead of hours of cached negatives.
        blockTTL = "1m";

        loading = {
          refreshPeriod = "24h";
          # Same reasoning as `upstreams.init.strategy`: start serving now, load
          # the lists in the background. Without this a slow or unreachable list
          # source delays DNS for the whole house at boot.
          strategy = "fast";
          maxErrorsPerSource = 5;
          downloads = {
            # Keep a copy of every downloaded list under the unit's
            # StateDirectory. Without it blocky is stateless and `strategy =
            # fast` means a boot with no WAN comes up blocking *nothing* until
            # the downloads land; with it the lists are already there, and a
            # refresh that finds a source unreachable falls back to the copy on
            # disk instead of dropping the group. It also makes the daily
            # refresh conditional (If-None-Match), so an unchanged list is not
            # re-fetched.
            cachePath = "${stateDir}/lists";
            timeout = "60s";
            attempts = 5;
            cooldown = "10s";
          };
        };
      };

      caching = {
        minTime = "5m";
        maxTime = "6h";
        # Refresh popular entries before they expire, so the common case is a
        # cache hit and never a round trip to the WAN.
        prefetching = true;
      };

      # Local names. A mapping also covers subdomains of the mapped name but not
      # its parent, so `git.mauderer.work` here does not capture the rest of the
      # zone.
      customDNS = {
        customTTL = "1h";
        # Answer an unmapped type (AAAA) for a mapped name with an empty NOERROR
        # instead of passing it upstream. This is what makes the split-horizon
        # entry work at all: without it a dual-stack client would get the public
        # AAAA from Cloudflare and leave the LAN anyway.
        filterUnmappedTypes = true;
        mapping = {
          "home-server.lan" = serverLanAddress;
          # Split horizon: the forge's public name resolves to the box itself on
          # the LAN, so a clone from the desktop stays on the wire instead of
          # going out to Cloudflare and back in through NAT hairpin. TLS still
          # terminates in NPM, which serves the same certificate either way.
          "git.mauderer.work" = serverLanAddress;
        };
      };

      # The router is authoritative for its own DHCP clients: forward its zone
      # and the LAN's reverse zone back to it instead of asking the internet
      # about names it invented. `fallbackUpstream = false` keeps a miss here a
      # miss, rather than leaking an internal name to Cloudflare.
      conditional = {
        fallbackUpstream = false;
        mapping = {
          "fritz.box" = router;
          "178.168.192.in-addr.arpa" = router;
        };
      };

      # Resolve client IPs to names (via the router) so the API's stats and any
      # debug log say "desktop" instead of an address.
      clientLookup.upstream = router;

      # No query log: the point of running the resolver here rather than at the
      # ISP is that nobody keeps a record of what this house looks up.
      queryLog.type = "none";

      log.level = "info";
    };
  };

  # The `blocky` CLI, for the things that are deliberately not declarative —
  # `blocky --apiPort 4001 blocking disable --duration 10m` when a blocked
  # domain is in the way, `blocky --apiPort 4001 query <name>` to see which
  # resolver answered, `blocky --apiPort 4001 lists refresh` after a list edit.
  environment.systemPackages = [ config.services.blocky.package ];

  networking = {
    # Resolve through blocky on the box itself, so its own traffic (and every
    # container's, since podman's DNS forwards to the host's resolvers) is
    # filtered and sees the local names. openresolv puts 127.0.0.1 first and
    # leaves the DHCP-provided servers behind it, so a dead blocky costs blocking
    # and local names — not the box's ability to resolve at all.
    resolvconf.useLocalResolver = true;

    # `extraInputRules` is nftables-only and silently ignored under iptables,
    # which would leave DNS unreachable rather than merely unrestricted. Same
    # defaulting as forgejo.nix: core/hardening.nix already turns nftables on for
    # every host, and this keeps the module honest on its own (the VM test node
    # relies on it).
    nftables.enable = lib.mkDefault true;

    # :53 is never globally open — an open resolver reachable from the WAN is an
    # amplification reflector, and this box's WAN surface is meant to stay UDP
    # 51820 + TCP 80/443. Admitted from the LAN (the clients) and the VPN (a
    # roaming laptop pointed at 10.100.0.1). UDP is the normal path; TCP carries
    # answers too long for a datagram and is required of any real resolver.
    #
    # Containers need no rule: they resolve through aardvark-dns on their own
    # bridge gateway, which forwards to the host's resolvers — and the host's
    # first resolver is blocky on 127.0.0.1, reached inside the host's own
    # namespace.
    #
    # IPv4 only, deliberately: the box's IPv6 address is a dynamic ISP-prefix GUA
    # (that is what cloudflare-ddns.nix exists for), so there is no stable v6
    # address for clients to be pointed at in the first place.
    firewall.extraInputRules = ''
      ip saddr { ${lanSubnet}, ${vpnSubnet} } udp dport ${toString dnsPort} accept
      ip saddr { ${lanSubnet}, ${vpnSubnet} } tcp dport ${toString dnsPort} accept
    '';
  };
}
