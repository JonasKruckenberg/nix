{ config, ... }:
{
  services.caddy.enable = true;

  services.caddy.virtualHosts = {
    "https://${config.services.grafana.settings.server.domain}" = {
      extraConfig = ''
        # This will create a new node at grafana.$TAILNET_NAME.ts.net
        bind tailscale/grafana
        # Enables the Tailscale authentication provider
        tailscale_auth
        # Forwards your Tailscale user ID to Grafana. Usually your email address.
        reverse_proxy ${config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port} {
          header_up X-Webauth-User {http.auth.user.tailscale_user}
        }
      '';
    };
  };

  services.grafana = {
    enable = true;
    settings = {
      "auth.proxy" = {
        # Enable proxy-based authentication
        enabled = true;
        # Automatically create new accounts for people who access the service
        auto_sign_up = true;
        # Do not store login cookies, instead always relying on proxy authentication
        enable_login_token = false;
      };
      server = {
        domain = "grafana.jonaskruckenberg.ts.net";
        http_addr = "127.0.0.1";
        http_port = 2342;
      };
    };
  };
}
