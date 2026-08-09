# Dynamic DNS for `mauderer.work` and the wildcard record `*.mauderer.work`.
#
# The ISP hands out a dynamic IPv6 prefix, so the server's global address changes
# whenever the line reconnects. `cloudflare-dyndns` discovers the current public
# address (via ipv6.icanhazip.com / api6.ipify.org) and PUTs it into Cloudflare's
# AAAA records, proxied (orange cloud). It runs every five minutes and caches the
# last-published address, so a steady state costs one HTTP request and no API
# write. A missing record is created rather than only updated, so neither name has
# to be seeded by hand.
#
# Both names are listed because a wildcard does not cover the zone apex: with only
# `*.mauderer.work`, `test.mauderer.work` resolves and `mauderer.work` returns
# NXDOMAIN. The same asymmetry applies to certificates — a `*.mauderer.work` cert
# does not cover the apex either, so both names have to be on it.
#
# Only AAAA: `ipv4 = false` (the tool is invoked with `-no-4`). Nothing publishes
# an A record for this zone.
#
# Interaction with reverse-proxy.nix: because this record is *proxied*, requests
# to `*.mauderer.work` arrive from Cloudflare's edge rather than from the client,
# and NPM's HTTP-01 challenges traverse the proxy. That works, but DNS-01 is the
# robust option for a proxied wildcard — see the header of reverse-proxy.nix.
#
# Cloudflare must be able to reach the box over IPv6 on 80/443 for the proxy to
# have an origin: the firewall already allows both (allowedTCPPorts covers v6),
# but the upstream router has to forward inbound IPv6 to this host.
#
# `vpn.mauderer.work` is the WireGuard endpoint (see net/home-server-client.nix).
# WireGuard is UDP; Cloudflare's proxy only carries HTTP/S, so the proxied
# wildcard above resolves it to a Cloudflare edge address that drops the UDP.
# The endpoint therefore needs its OWN grey-cloud (DNS-only) AAAA pointing at the
# WAN address. `--proxied` is a per-run flag in the upstream tool, so this can't
# join the `domains` list above — it runs as a second instance below, unproxied,
# with its own cache. A specific `vpn` record shadows the wildcard for that name.
{
  config,
  pkgs,
  lib,
  ...
}:
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
  # needs to reach as the proxy origin. core/networking.nix additionally pins the
  # interface ID of that stable address to EUI-64, so only the prefix moves.
  networking.tempAddresses = "disabled";

  services.cloudflare-dyndns = {
    enable = true;
    domains = [
      "mauderer.work"
      "*.mauderer.work"
    ];
    apiTokenFile = config.sops.secrets.cloudflare-api-token.path;
    proxied = true;
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

  # Second instance: the grey-cloud (unproxied) AAAA for the WireGuard endpoint.
  # Mirrors the upstream unit (DynamicUser + LoadCredential + legacy-token guard)
  # but with its own StateDirectory/cache so the two runs don't clobber each
  # other, and `-no-4 -6` with NO `--proxied`.
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
        -no-4 -6 vpn.mauderer.work
    '';
  };
}
