{ config, inputs, ... }:
{
  imports = [ inputs.bulletin.nixosModules.bulletin ];

  # SMTP credentials live in an agenix secret, decrypted at activation into a root-only file
  # under /run/agenix. The bulletin module feeds it to the service via systemd EnvironmentFile,
  # so the Proton token never lands in the Nix store or the world-readable journal. The file is
  # an env file (KEY=value per line); see secrets/secrets.nix for the recipient keys.
  age.secrets.bulletin-smtp.file = ../secrets/bulletin-smtp.age;

  services.bulletin = {
    enable = true;
    # Health on 127.0.0.1:3000, Prometheus on 127.0.0.1:9464, JSON logs to journald
    # (picked up by Alloy → Loki). Email goes out over Proton SMTP.
    email = {
      transport = "smtp";
      # Visible From address; must be an address you own on the Proton account/custom domain.
      from = "bulletin@jonaskruckenberg.de";
      # BULLETIN_SMTP_HOST / USERNAME / PASSWORD (/ PORT / TLS) are read from this env file.
      smtpSecretFile = config.age.secrets.bulletin-smtp.path;
    };
  };

  # Scrape Bulletin's exporter alongside the node exporter (see services/prometheus.nix).
  services.prometheus.scrapeConfigs = [
    {
      job_name = "bulletin";
      static_configs = [ { targets = [ config.services.bulletin.metrics.addr ]; } ];
    }
  ];
}
