{ inputs, ... }:
{
  # The metafactory, refractory's Linear agent (github:JonasKruckenberg/refractory, branch `main`,
  # build/metafactory). It runs inside the dev shell of its own jj checkout of refractory, beside
  # that checkout's FoundationDB, so this host builds nothing of refractory's beyond the service.
  #
  # Kept by hand, outside this repository:
  # - the tailnet policy's `funnel` nodeAttr for this host;
  # - the Linear app (its webhook: https://ardmore.tailf383a6.ts.net/linear);
  # - as the metafactory user (`sudo -u metafactory -H bash`): the checkout, cloned with
  #   `jj git clone --colocate` into /var/lib/metafactory/refractory, and the agents' CLIs logged
  #   in inside its `nix develop` (`claude`, then `codex login`). Until the checkout exists both
  #   services are skipped; start them by hand once it does.
  flake.modules.nixos.metafactory =
    { config, pkgs, ... }:
    let
      cfg = config.services.metafactory;
      # Units that need the checkout: skipped, not failed, before it exists, so a switch (and
      # autoUpgrade with it) doesn't fail on a fresh host.
      needsCheckout.unitConfig.ConditionPathExists = "${cfg.repo}/flake.nix";
    in
    {
      imports = [ inputs.refractory.nixosModules.metafactory ];

      # `access-tokens = github.com=<PAT>`, read access to refractory, which is private; without it
      # every evaluation of this host fails, autoUpgrade included. The running generation decrypts
      # it for the next one's evaluation, so a fresh install needs the token passed by hand once
      # (`--option access-tokens`).
      age.secrets.github-token.file = ../../secrets/github-token.conf.age;
      nix.extraOptions = ''
        !include ${config.age.secrets.github-token.path}
      '';

      # Root-only: systemd reads them and hands them to the service as credentials.
      age.secrets.metafactory-webhook-secret.file = ../../secrets/metafactory-webhook-secret.age;
      age.secrets.metafactory-linear-client-secret.file = ../../secrets/metafactory-linear-client-secret.age;

      services.metafactory = {
        enable = true;
        clientId = "32bdcc43e392b988aa99e7f98f57e170";
        webhookSecretFile = config.age.secrets.metafactory-webhook-secret.path;
        clientSecretFile = config.age.secrets.metafactory-linear-client-secret.path;
        email = "metafactory@users.noreply.github.com";
        # The module's own Funnel unit can hang a switch; tailscale-funnel below can't.
        funnel = false;
      };

      systemd.services.metafactory = needsCheckout;
      systemd.services.metafactory-fdb = needsCheckout;

      # `tailscale funnel --bg` persists in tailscaled's state, not here; reapplying it on every boot
      # and switch means a reset node or a new machine gets it back. Idempotent, and it leaves the
      # node's Tailscale Services (svc:grafana) alone.
      #
      # Without the tailnet policy's `funnel` nodeAttr, `tailscale funnel` prints an enablement URL
      # and either exits 0 having done nothing or waits for someone to click it. So: a start timeout
      # (a wait would otherwise block `nixos-rebuild switch`, autoUpgrade's included), and success
      # only once Funnel is actually on; failures retry, e.g. while tailscaled isn't logged in yet.
      systemd.services.tailscale-funnel = {
        description = "Tailscale Funnel to the metafactory's webhook";
        after = [ "tailscaled.service" ];
        wants = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [
          config.services.tailscale.package
          pkgs.jq
        ];
        script = ''
          tailscale funnel --bg ${toString cfg.port}
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
