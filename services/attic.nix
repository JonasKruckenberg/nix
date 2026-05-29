{ inputs, config, ... }:
# Self-hosted Nix binary cache.
#
# Client-side, after deploy:
#   1. Mint an admin token:
#        sudo atticd-atticadm make-token --sub admin --validity 1y \
#          --pull '*' --push '*' --create-cache '*' --configure-cache '*'
#   2. From a tailnet workstation: attic login + `attic cache create nix-cache`.
#      The printed `nix-cache:<base64>` signing key goes into the NIX_CONFIG of
#      any spindle workflow that should pull from this cache.
{
  imports = [
    inputs.attic.nixosModules.atticd
  ];

  age.secrets.attic-server-env.file = ../secrets/attic-server.env.age;

  services.atticd = {
    enable = true;
    environmentFile = config.age.secrets.attic-server-env.path;
    settings = {
      listen = "[::]:8080";
      storage = {
        type = "local";
        path = "/var/lib/atticd/storage";
      };
      chunking = {
        # NARs at or above this size are chunked (0 disables, 1 chunks all).
        nar-size-threshold = 64 * 1024; # 64 KiB
        min-size = 16 * 1024; # 16 KiB
        avg-size = 64 * 1024; # 64 KiB
        max-size = 256 * 1024; # 256 KiB
      };
    };
  };
}
