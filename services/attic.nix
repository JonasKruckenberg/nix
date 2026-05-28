{ inputs, ... }:
# Self-hosted Nix binary cache. Cache name is `nix-cache`.
#
# Listens on 0.0.0.0:8080 so spindle pipeline containers can reach it via the
# docker bridge gateway (http://172.17.0.1:8080/nix-cache). The host firewall
# whitelists tailscale0 + ssh only, so port 8080 is not reachable from the
# public internet.
#
# Bootstrap (one-time, after first deploy):
#   1. Generate the HS256 token secret on the host:
#        sudo install -d -m 700 -o atticd -g atticd /var/lib/atticd
#        printf 'ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64=%s\n' \
#          "$(openssl rand 64 | base64 -w0)" | \
#          sudo tee /var/lib/atticd/server.env > /dev/null
#        sudo chmod 600 /var/lib/atticd/server.env
#        sudo systemctl restart atticd
#   2. Mint an admin token:
#        sudo atticd-atticadm make-token --sub admin --validity 1y \
#          --pull '*' --push '*' --create-cache '*' --configure-cache '*'
#   3. From a workstation on the tailnet:
#        attic login ardmore http://<ardmore-ts-ip>:8080 <token>
#        attic cache create nix-cache
#      `attic cache create` prints the cache's signing public key — copy that
#      `nix-cache:<base64>` value into the NIX_CONFIG of any spindle workflow
#      that should pull from this cache.
{
  imports = [
    inputs.attic.nixosModules.atticd
  ];

  services.atticd = {
    enable = true;
    environmentFile = "/var/lib/atticd/server.env";
    settings = {
      listen = "[::]:8080";
      storage = {
        type = "local";
        path = "/var/lib/atticd/storage";
      };
      chunking = {
        # The minimum NAR size to trigger chunking
        #
        # If 0, chunking is disabled entirely for newly-uploaded NARs.
        # If 1, all NARs are chunked.
        nar-size-threshold = 64 * 1024; # 64 KiB

        # The preferred minimum size of a chunk, in bytes
        min-size = 16 * 1024; # 16 KiB

        # The preferred average size of a chunk, in bytes
        avg-size = 64 * 1024; # 64 KiB

        # The preferred maximum size of a chunk, in bytes
        max-size = 256 * 1024; # 256 KiB
      };
    };
  };
}
