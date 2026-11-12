{ inputs, ... }:
{
  # The metafactory, refractory's Linear agent (github:JonasKruckenberg/refractory, branch `main`,
  # build/metafactory). It runs inside the dev shell of its own jj checkout of refractory, beside
  # that checkout's FoundationDB, so this host builds nothing of refractory's beyond the service.
  #
  # The module clones the checkout and Claude Code authenticates with a token from secrets/, so the
  # only login on the box is Codex's: `sudo metafactory-codex-login`.
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
        claudeTokenFile = config.age.secrets.metafactory-claude-token.path;
        # The module's own Funnel unit can hang a switch; tailscale-funnel below can't.
        funnel = false;
      };

      # The token `claude setup-token` prints on a machine with a browser, alone in the file.
      age.secrets.metafactory-claude-token.file = ../../secrets/metafactory-claude-token.age;

      # refractory is private, and the metafactory clones it and fetches its main before every run,
      # as its own user: that user (and so its agents) reads the host's token for refractory, a
      # second decryption of github-token above, through a git credential helper. jj fetches
      # through git. For every other user the file is unreadable and the helper says nothing.
      age.secrets.metafactory-github-token = {
        file = ../../secrets/github-token.conf.age;
        owner = "metafactory";
      };
      programs.git = {
        enable = true;
        config.credential."https://github.com".helper =
          let
            token = config.age.secrets.metafactory-github-token.path;
            sed = lib.getExe pkgs.gnused;
          in
          ''!f() { test -r ${token} && echo username=x-access-token && echo "password=$(${sed} -n 's/^access-tokens *= *github[.]com=//p' ${token})"; }; f'';
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
