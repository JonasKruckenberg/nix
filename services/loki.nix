{ ... }:
let
  lokiAddr = "127.0.0.1";
  lokiPort = 3100;
in
{
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;
      # Opt out of anonymous usage statistics sent to stats.grafana.org
      analytics.reporting_enabled = false;
      server = {
        http_listen_address = lokiAddr;
        http_listen_port = lokiPort;
        log_level = "warn";
      };
      # Single-binary monolithic mode: one process, no clustering
      common = {
        ring = {
          instance_addr = "127.0.0.1";
          kvstore.store = "inmemory";
        };
        replication_factor = 1;
        path_prefix = "/var/lib/loki";
      };
      schema_config.configs = [
        {
          from = "2025-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];
      storage_config.filesystem.directory = "/var/lib/loki/chunks";
    };
  };

  services.grafana.provision = {
    enable = true;
    datasources.settings = {
      apiVersion = 1;
      datasources = [
        {
          name = "Loki";
          type = "loki";
          url = "http://${lokiAddr}:${toString lokiPort}";
          access = "proxy";
          isDefault = false;
        }
      ];
    };
  };
}
