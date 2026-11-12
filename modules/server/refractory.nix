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

  # refractory (github:JonasKruckenberg/refractory, branch `release`, which its CI fast-forwards
  # to each main commit that passed): its control plane, the FoundationDB it keeps
  # state in, and the public Funnel its webhooks arrive through. The control plane itself is not
  # enabled yet: it has no webhook endpoint and can't be handed its secrets until slice 6.
  #
  # secrets/github-token.conf.age is `access-tokens = github.com=<PAT>`, read access to refractory,
  # which is private; without it every evaluation of this host fails, autoUpgrade included. The
  # running generation decrypts it for the next one's evaluation, so a fresh install needs the
  # token passed by hand once (`--option access-tokens`). The service's own secrets will join it
  # in ./secrets when the control plane is enabled.
  #
  # Kept by hand, outside this repository: the tailnet policy's `funnel` nodeAttr for this host.
  flake.modules.nixos.refractory =
    { config, pkgs, ... }:
    let
      # Public https://<host>.<tailnet>.ts.net (443) is forwarded here. Only ever a webhook-only
      # listener (slice 6 adds one): never the control plane's `listen`, which is its whole API, nor
      # `metrics_listen`. Until then nothing listens and the Funnel answers 502.
      webhookPort = 7702;
    in
    {
      imports = [ inputs.refractory.nixosModules.default ];

      age.secrets.github-token.file = ../../secrets/github-token.conf.age;
      nix.extraOptions = ''
        !include ${config.age.secrets.github-token.path}
      '';

      # On first start (no /etc/foundationdb/fdb.cluster) the module creates the cluster file and
      # runs `configure new single ssd` itself. The client the control plane links is 7.3 (its
      # `fdb-7_3` feature); the package must stay on 7.3 with it.
      services.foundationdb = {
        enable = true;
        package = pkgs.foundationdb;
      };

      # `tailscale funnel --bg` persists in tailscaled's state, not here; reapplying it on every boot
      # and switch means a reset node or a new machine gets it back. Idempotent, and it leaves the
      # node's Tailscale Services (svc:grafana) alone.
      #
      # Without the tailnet policy's `funnel` nodeAttr, `tailscale funnel` prints an enablement URL
      # and either exits 0 having done nothing or waits for someone to click it. So: a start timeout
      # (a wait would otherwise block `nixos-rebuild switch`, autoUpgrade's included), and success
      # only once Funnel is actually on; failures retry, e.g. while tailscaled isn't logged in yet.
      systemd.services.tailscale-funnel = {
        description = "Tailscale Funnel to refractory's webhook listener";
        after = [ "tailscaled.service" ];
        wants = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [
          config.services.tailscale.package
          pkgs.jq
        ];
        script = ''
          tailscale funnel --bg ${toString webhookPort}
          host=$(tailscale status --json | jq -er '.Self.DNSName | rtrimstr(".")')
          tailscale serve status --json | jq -e --arg k "$host:443" '.AllowFunnel[$k] == true' > /dev/null
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = "60s";
          Restart = "on-failure";
          RestartSec = "30s";
        };
        unitConfig.StartLimitIntervalSec = 0;
      };
    };
}
