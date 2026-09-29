_: {
  # Single-node observability: journald -> Alloy -> Loki, node exporter -> Prometheus, both into
  # Grafana. Everything binds to loopback; Grafana trusts an auth proxy in front of it.
  flake.modules.nixos.observability =
    { config, ... }:
    let
      loki = config.services.loki.configuration.server;
      lokiUrl = "http://${loki.http_listen_address}:${toString loki.http_listen_port}";
    in
    {
      services.grafana = {
        enable = true;
        settings = {
          # 26.05 dropped the built-in default for `secret_key`. This is the historical upstream
          # default, so keeping it leaves existing DB secrets decryptable. It was the public nixpkgs
          # default for years and is not treated as sensitive.
          security.secret_key = "SW2YcwTIb9zpOOhoPsMm";
          "auth.proxy" = {
            enabled = true;
            auto_sign_up = true;
            enable_login_token = false;
          };
          server = {
            domain = "grafana.jonaskruckenberg.ts.net";
            http_addr = "127.0.0.1";
            http_port = 2342;
          };
        };
        provision = {
          enable = true;
          datasources.settings = {
            apiVersion = 1;
            datasources = [
              {
                name = "Prometheus";
                type = "prometheus";
                url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
                isDefault = true;
                editable = false;
              }
              {
                name = "Loki";
                type = "loki";
                url = lokiUrl;
                access = "proxy";
                isDefault = false;
              }
            ];
          };
        };
      };

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
              { targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ]; }
            ];
          }
        ];
      };

      services.loki = {
        enable = true;
        configuration = {
          auth_enabled = false;
          analytics.reporting_enabled = false;
          server = {
            http_listen_address = "127.0.0.1";
            http_listen_port = 3100;
            log_level = "warn";
          };
          # Single-binary monolithic mode: one process, no clustering.
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

      services.alloy.enable = true;
      # All *.alloy files under /etc/alloy are loaded; the module already joins systemd-journal.
      environment.etc."alloy/config.alloy".text = ''
        // Promote selected journal fields to Loki stream labels.
        loki.relabel "journal" {
          forward_to = []
          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label  = "unit"
          }
          rule {
            source_labels = ["__journal_priority_keyword"]
            target_label  = "level"
          }
        }

        loki.source.journal "read" {
          forward_to    = [loki.write.local.receiver]
          relabel_rules = loki.relabel.journal.rules
          labels        = { job = "systemd-journal" }
        }

        loki.write "local" {
          endpoint {
            url = "${lokiUrl}/loki/api/v1/push"
          }
        }
      '';
    };
}
