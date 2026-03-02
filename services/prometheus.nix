{ config, ... }:
{
  services.prometheus = {
    enable = true;

    exporters.node = {
      enable = true;
      port = 9000;
      enabledCollectors = [
        "systemd"
        "edac"
        "tcpstat"
      ];
    };

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ];
          }
        ];
      }
    ];
  };

  services.grafana.provision.datasources.settings.datasources = [
    # Provisioning a built-in data source
    {
      name = "Prometheus";
      type = "prometheus";
      url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
      isDefault = true;
      editable = false;
    }
  ];
}
