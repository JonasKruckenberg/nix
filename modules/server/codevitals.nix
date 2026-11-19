{ inputs, ... }:
{
  # cv (github:mainmatter/codevitals-app): mirrors the repositories its GitHub App is installed on
  # and derives commit, pull request and code facts from them into Postgres. Its module brings the
  # Postgres, and, since Prometheus runs here, its scrape jobs, the Postgres exporter and alerts.
  # Logs reach Loki through the journal like every unit's. Traces stay off: nothing here takes OTLP.
  #
  # Kept by hand, outside this repository: the GitHub App (its callback, setup and webhook URLs are
  # https://ardmore.<tailnet>.ts.net/{callback,setup,webhook}; see the head of cv's src/main.rs),
  # and the tailnet policy's `funnel` nodeAttr for this host.
  flake.modules.nixos.codevitals =
    { config, pkgs, ... }:
    let
      # Public https://<host>.<tailnet>.ts.net (443) is forwarded here. Everything cv serves on it
      # is meant for the internet; its metrics have a listener of their own.
      port = 3000;
    in
    {
      imports = [ inputs.codevitals.nixosModules.default ];

      age.secrets = {
        cv-private-key.file = ../../secrets/cv-private-key.age;
        cv-client-secret.file = ../../secrets/cv-client-secret.age;
        cv-webhook-secret.file = ../../secrets/cv-webhook-secret.age;
      };

      services.cv = {
        enable = true;
        listen = "127.0.0.1:${toString port}";
        appId = 5832317;
        clientId = "Iv23liqh8y4O9ZOSQDbh";
        privateKeyFile = config.age.secrets.cv-private-key.path;
        clientSecretFile = config.age.secrets.cv-client-secret.path;
        webhookSecretFile = config.age.secrets.cv-webhook-secret.path;
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
        description = "Tailscale Funnel to cv";
        after = [ "tailscaled.service" ];
        wants = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [
          config.services.tailscale.package
          pkgs.jq
        ];
        script = ''
          tailscale funnel --bg ${toString port}
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
