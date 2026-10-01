# Dynamic DNS for `mauderer.work`, the wildcard `*.mauderer.work`, and the
# WireGuard endpoint `vpn.mauderer.work`.
#
# The ISP hands out a dynamic address on both families, so the server's public
# addresses change whenever the line reconnects. `cloudflare-dyndns` discovers
# the current ones (via icanhazip / ipify) and PUTs them into Cloudflare. It runs
# every five minutes and caches the last-published address, so a steady state
# costs one HTTP request and no API write. A missing record is created rather
# than only updated, so neither name has to be seeded by hand.
#
# ## Two instances, because the two records need opposite settings
#
# 1. `cloudflare-dyndns` (upstream unit): the **proxied** (orange-cloud) web
#    records. Both `mauderer.work` and `*.mauderer.work` are listed because a
#    wildcard does not cover the zone apex: with only `*.mauderer.work`,
#    `test.mauderer.work` resolves and `mauderer.work` returns NXDOMAIN. The same
#    asymmetry applies to certificates — a `*.mauderer.work` cert does not cover
#    the apex either, so both names have to be on it.
#
# 2. `cloudflare-dyndns-vpn` (below): the **grey-cloud** (DNS-only) record for
#    the WireGuard endpoint. WireGuard is UDP; Cloudflare's proxy only carries
#    HTTP/S, so the proxied wildcard above would resolve `vpn.mauderer.work` to a
#    Cloudflare edge address that drops the UDP. The endpoint therefore needs its
#    own unproxied record pointing straight at the WAN address, and a specific
#    `vpn` record shadows the wildcard for that name. `--proxied` is a per-run
#    flag in the upstream tool, so this cannot join the `domains` list above — it
#    is a second unit with its own cache.
#
# ## Address families
#
# The endpoint record is **dual-stack (A + AAAA)**. It used to be AAAA-only,
# because the line was DS-Lite: there was no public IPv4 to forward UDP 51820
# through, so a v4 endpoint could not exist. The ISP now hands out a real (still
# dynamic) IPv4, which is what makes port forwarding work — and an A record is
# what lets a client on an IPv4-only network (mobile data, hotel wifi, most
# corporate guest networks) find the endpoint at all. That was the common failure
# behind "the VPN is unreachable from outside": AAAA-only means only v6-capable
# clients ever got an address to hand WireGuard. The router must forward inbound
# UDP 51820 over IPv4 to this host for the new record to be useful.
#
# Both families are published from one run, so a failure to discover either one
# fails the unit (and drops the cache, forcing a full re-publish next run). That
# is deliberate: half a dual-stack endpoint is exactly the state that strands
# whichever clients are on the missing family, and `hs-unit-failed` in alerts.nix
# is what surfaces it. blackbox.nix additionally probes a *public* resolver for
# both records, which is the check that the record the world sees is current.
#
# The **proxied** records stay AAAA-only on purpose. Cloudflare's edge is what
# answers for those names on both families regardless, so v4 visitors are already
# served; the A record here would only add a second *origin* address, and
# Cloudflare would then be free to reach the origin over IPv4 — which needs
# inbound 80/443 forwarded over v4 as well. Flip `ipv4 = true` below once that
# forwarding is in place and verified, not before: an origin address the proxy
# cannot reach turns into 522s on git./ntfy.mauderer.work.
#
# Interaction with reverse-proxy.nix: because those records are *proxied*,
# requests to `*.mauderer.work` arrive from Cloudflare's edge rather than from
# the client, and NPM's HTTP-01 challenges traverse the proxy. That works, but
# DNS-01 is the robust option for a proxied wildcard — see the header of
# reverse-proxy.nix.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  # The WireGuard endpoint's hostname, kept as a literal in sync with
  # net/home-server-client.nix (`endpoint`) and blackbox.nix (`dnsOnlyHosts`) —
  # the same convention metrics.nix uses for its siblings' ports.
  vpnHost = "vpn.mauderer.work";
in
{
  # API token, decrypted to /run/secrets at activation (keyless CI: the encrypted
  # file just has to exist). The file must hold the BARE token — no
  # `CLOUDFLARE_API_TOKEN=` prefix; the upstream unit errors out on that. Scope
  # it to Zone:DNS:Edit + Zone:Zone:Read on mauderer.work only.
  sops.secrets.cloudflare-api-token = {
    sopsFile = ../../../secrets/home-server/cloudflare.yaml;
  };

  # IPv6 privacy extensions must be off. With them on (the NixOS default,
  # use_tempaddr=2) the kernel *prefers* a rotating temporary address for
  # outbound connections, so the address the discovery service reports is a
  # short-lived one that deprecates within a day — we would publish an AAAA that
  # is dead long before the next prefix change. Disabling them makes the reported
  # address the stable per-prefix SLAAC address, which is also the one Cloudflare
  # needs to reach as the proxy origin. server/ipv6-interface-id.nix additionally
  # pins the interface ID of that stable address, so only the prefix moves.
  # IPv4 has no equivalent: the WAN address is the router's, and the discovery
  # service reports it whatever this host's LAN address is.
  networking.tempAddresses = "disabled";

  services.cloudflare-dyndns = {
    enable = true;
    domains = [
      "mauderer.work"
      "*.mauderer.work"
    ];
    apiTokenFile = config.sops.secrets.cloudflare-api-token.path;
    proxied = true;
    # AAAA only — see "Address families" in the header before turning this on.
    ipv4 = false;
    ipv6 = true;
  };

  # The upstream unit only orders after network.target, which is up before the
  # interface has a global address; a first run at boot would then find no IPv6
  # and exit non-zero (the timer retries five minutes later, but the unit shows
  # as failed). network-online.target waits for an actually-configured link.
  systemd.services.cloudflare-dyndns = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  # Second instance: the grey-cloud (unproxied) A + AAAA for the WireGuard
  # endpoint. Mirrors the upstream unit (DynamicUser + LoadCredential +
  # legacy-token guard) but with its own StateDirectory/cache so the two runs
  # don't clobber each other, and `-4 -6` with NO `--proxied`.
  #
  # The cache is per family (separate `ipv4`/`ipv6` sections), so switching this
  # unit from `-no-4 -6` to `-4 -6` needs no cache reset: the v4 half is simply
  # empty on the first dual-stack run and the A record is created then.
  systemd.services.cloudflare-dyndns-vpn = {
    description = "CloudFlare Dynamic DNS Client (grey-cloud WireGuard endpoint)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    startAt = "*:0/5";

    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      StateDirectory = "cloudflare-dyndns-vpn";
      LoadCredential = [ "apiToken:${config.sops.secrets.cloudflare-api-token.path}" ];
    };

    script = ''
      export CLOUDFLARE_API_TOKEN_FILE=''${CREDENTIALS_DIRECTORY}/apiToken
      token=$(< "''${CLOUDFLARE_API_TOKEN_FILE}")
      if [[ $token == CLOUDFLARE_API_TOKEN* ]]; then
        echo "Error: api token starts with 'CLOUDFLARE_API_TOKEN='. Store just the token." >&2
        exit 1
      fi
      exec ${lib.getExe pkgs.cloudflare-dyndns} \
        --cache-file /var/lib/cloudflare-dyndns-vpn/ip.cache \
        -4 -6 ${vpnHost}
    '';
  };
}
