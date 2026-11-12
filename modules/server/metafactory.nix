{ inputs, ... }:
{
  # The metafactory, refractory's Linear agent (github:JonasKruckenberg/refractory, branch `main`,
  # build/metafactory). It runs inside the dev shell of its own jj checkout of refractory, beside
  # that checkout's FoundationDB, so this host builds nothing of refractory's beyond the service.
  #
  # The host clones the checkout itself (metafactory-checkout) and Claude Code authenticates with a
  # token from secrets/, so the only login on the box is Codex's: `sudo metafactory-codex-login`.
  #
  # Kept by hand, outside this repository:
  # - the tailnet policy's `funnel` nodeAttr for this host;
  # - the Linear app (webhook https://ardmore.tailf383a6.ts.net/linear, callback …/callback),
  #   installed once by opening https://ardmore.tailf383a6.ts.net/install.
  flake.modules.nixos.metafactory =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.metafactory;
      nix = lib.getExe config.nix.package;
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

      # `CLAUDE_CODE_OAUTH_TOKEN=<token>`, from `claude setup-token` on a machine with a browser.
      # The agents inherit it through `nix develop`; they run as the metafactory user, which could
      # read a login on disk just the same.
      age.secrets.metafactory-claude-token.file = ../../secrets/metafactory-claude-token.env.age;
      systemd.services.metafactory.serviceConfig.EnvironmentFile = config.age.secrets.metafactory-claude-token.path;

      # Clones refractory into cfg.repo once, with the host's read token (github-token above). The
      # token stays root's: git gets it from a credential helper reading this unit's environment,
      # never argv or the checkout's config, and the metafactory user gets a plain https remote.
      # Cloned beside and moved into place, so a failed clone leaves nothing that looks done.
      systemd.services.metafactory-checkout = {
        description = "Clone the metafactory's checkout of refractory";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        unitConfig.ConditionPathExists = "!${cfg.repo}";
        path = [
          pkgs.git
          pkgs.jujutsu
          pkgs.gnused
          pkgs.util-linux # runuser
        ];
        script = ''
          GITHUB_TOKEN=$(sed -n 's/^access-tokens *= *github\.com=//p' ${config.age.secrets.github-token.path})
          export GITHUB_TOKEN
          tmp=${cfg.repo}.cloning
          rm -rf "$tmp"
          git -c credential.helper= -c credential.helper='!f() { echo username=x-access-token; echo "password=$GITHUB_TOKEN"; }; f' \
            clone https://github.com/JonasKruckenberg/refractory "$tmp"
          chown -R metafactory:metafactory "$tmp"
          cd "$tmp"
          runuser -u metafactory -- env HOME=/var/lib/metafactory jj git init --colocate
          runuser -u metafactory -- env HOME=/var/lib/metafactory jj bookmark track main --remote=origin
          mv "$tmp" ${cfg.repo}
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
      systemd.services.metafactory-fdb = {
        requires = [ "metafactory-checkout.service" ];
        after = [ "metafactory-checkout.service" ];
      };

      # Codex has no token to hand over like Claude's: its one login, by device code (a short code
      # entered on any device), stored in the metafactory user's ~/.codex.
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "metafactory-codex-login" ''
          cd ${cfg.repo}
          exec ${lib.getExe' pkgs.util-linux "runuser"} -u metafactory -- \
            env HOME=/var/lib/metafactory ${nix} develop ${cfg.repo} --command codex login --device-auth
        '')
      ];

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
