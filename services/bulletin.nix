{ config, inputs, ... }:
{
  imports = [ inputs.bulletin.nixosModules.bulletin ];

  services.bulletin = {
    enable = true;
    # Defaults are loopback-only: health on 127.0.0.1:3000, Prometheus on 127.0.0.1:9464,
    # JSON logs to journald (picked up by Alloy → Loki), and the `file` email transport
    # (writes .eml into /var/lib/bulletin/outbox). Switch to SMTP via email.smtpUrlFile later.
  };

  # Scrape Bulletin's exporter alongside the node exporter (see services/prometheus.nix).
  services.prometheus.scrapeConfigs = [
    {
      job_name = "bulletin";
      static_configs = [ { targets = [ config.services.bulletin.metrics.addr ]; } ];
    }
  ];
}
