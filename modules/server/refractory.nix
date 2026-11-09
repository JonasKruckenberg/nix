{ inputs, lib, ... }:
{
  # Built by CI's linux job (`nix build .#refractory`), which otherwise only evaluates ardmore: a
  # refractory that fails to build is caught before merge, not on the host. With nixpkgs followed,
  # it is the same derivation ardmore's services run.
  perSystem =
    { system, ... }:
    {
      packages = lib.optionalAttrs (system == "aarch64-linux") {
        refractory = inputs.refractory.packages.${system}.default;
      };
    };

  # refractory (github:JonasKruckenberg/refractory): its control plane, the FoundationDB it keeps
  # state in, and the public Funnel its webhooks arrive through. The control plane itself is not
  # enabled yet: it has no webhook endpoint and can't be handed its secrets until slice 6.
  #
  # Kept by hand on the host, never in the store:
  # - /etc/nix/github-token.conf: `access-tokens = github.com=<PAT>`, read access to refractory,
  #   which is private; without it every evaluation of this host fails, autoUpgrade included.
  # - /etc/refractory/*: the service's secrets, root-owned 0400.
  # - The tailnet policy's `funnel` nodeAttr for this host.
  flake.modules.nixos.refractory =
    { config, pkgs, ... }:
    let
      # Public https://<host>.<tailnet>.ts.net (443) is forwarded here: the webhook listener only,
      # never the executors' `listen` or `metrics_listen`.
      webhookPort = 7702;
    in
    {
      imports = [ inputs.refractory.nixosModules.default ];

      nix.extraOptions = ''
        !include /etc/nix/github-token.conf
      '';

      # On first start (no /etc/foundationdb/fdb.cluster) the module creates the cluster file and
      # runs `configure new single ssd` itself. The client the control plane links is 7.3 (its
      # `fdb-7_3` feature); the package must stay on 7.3 with it.
      services.foundationdb = {
        enable = true;
        package = pkgs.foundationdb;
      };

      # `tailscale funnel --bg` persists in tailscaled's state, not here; reapplying it on every boot
      # and switch means a reset node or a new machine gets it back. Idempotent.
      systemd.services.tailscale-funnel = {
        description = "Tailscale Funnel to refractory's webhook listener";
        after = [ "tailscaled.service" ];
        wants = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [ config.services.tailscale.package ];
        # tailscaled answers before it is logged in; fail and retry until it is.
        script = "tailscale funnel --bg ${toString webhookPort}";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "15s";
        };
        unitConfig.StartLimitIntervalSec = 0;
      };
    };
}
