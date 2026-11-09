_: {
  # Single-node observability: journald -> Alloy -> Loki, node exporter -> Prometheus, both into
  # Grafana; Prometheus alerts -> Alertmanager -> Telegram. Everything binds to loopback; Grafana
  # trusts an auth proxy in front of it.
  #
  # Kept by hand on the host: /etc/alertmanager/telegram.env (root, 0400) with TELEGRAM_BOT_TOKEN
  # and TELEGRAM_CHAT_ID. Without it Alertmanager fails to start.
  flake.modules.nixos.observability =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      host = config.networking.hostName;
      am = config.services.prometheus.alertmanager;
      # `$VARS` are filled in from the environment file by the module's envsubst when the service
      # starts. chat_id is unquoted, so it substitutes to the integer Alertmanager wants.
      alertmanagerConfig = ''
        route:
          receiver: telegram
          group_by: [alertname]
          group_wait: 30s
          group_interval: 5m
          repeat_interval: 12h
        receivers:
          - name: telegram
            telegram_configs:
              - bot_token: "$TELEGRAM_BOT_TOKEN"
                chat_id: $TELEGRAM_CHAT_ID
                send_resolved: true
      '';
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
        # Alertmanager (below) sends these to Telegram. The host group replaces what were Grafana
        # alerts; autoUpgrade is how this host gets every change, so its failing must not go
        # unnoticed either (the systemd collector above provides its metrics).
        rules = [
          (builtins.toJSON {
            groups = [
              {
                name = "host";
                rules = [
                  {
                    alert = "HostOutOfMemory";
                    expr = "avg_over_time(node_memory_MemAvailable_bytes[5m]) < 64 * 1024 * 1024";
                    for = "5m";
                    labels.severity = "critical";
                    annotations = {
                      summary = "${host} is running out of memory";
                      description = "Available memory averaged under 64 MiB for 5 minutes ({{ $value | humanize1024 }}B now).";
                    };
                  }
                  {
                    alert = "HostOomKill";
                    expr = "increase(node_vmstat_oom_kill[10m]) > 0";
                    labels.severity = "warning";
                    annotations = {
                      summary = "${host}: the kernel OOM-killed a process";
                      description = "journalctl -k -g 'Out of memory' --since -15min";
                    };
                  }
                  {
                    # i2c_*_0038 is the speaker amplifier (tas2764), whose reading isn't a chassis
                    # temperature.
                    alert = "HostTemperatureHigh";
                    expr = ''node_hwmon_temp_celsius{chip!~"i2c_.*_0038"} > 89'';
                    for = "5m";
                    labels.severity = "critical";
                    annotations = {
                      summary = "${host} is running hot";
                      description = "{{ $labels.chip }} {{ $labels.sensor }} has been over 89°C for 5 minutes ({{ $value | printf \"%.1f\" }}°C now).";
                    };
                  }
                  {
                    alert = "HostTemperatureAlarm";
                    expr = "node_hwmon_temp_alarm > 0";
                    for = "5m";
                    labels.severity = "critical";
                    annotations = {
                      summary = "${host} signalled a temperature alarm";
                      description = "{{ $labels.chip }} {{ $labels.sensor }} raised its hardware temperature alarm.";
                    };
                  }
                  {
                    # Every alert above reads node_exporter; without it they would all go quiet.
                    alert = "NodeExporterDown";
                    expr = ''up{job="node"} == 0 or absent(up{job="node"})'';
                    for = "5m";
                    labels.severity = "critical";
                    annotations.summary = "${host}: node_exporter isn't being scraped";
                  }
                ];
              }
            ];
          })
        ]
        ++ lib.optional config.system.autoUpgrade.enable (
          builtins.toJSON {
            groups = [
              {
                name = "nixos-upgrade";
                rules = [
                  {
                    alert = "NixosUpgradeFailed";
                    expr = ''node_systemd_unit_state{name="nixos-upgrade.service",state="failed"} == 1'';
                    for = "5m";
                    labels.severity = "warning";
                    annotations = {
                      summary = "${host}: autoUpgrade failed";
                      description = "Evaluation, build or switch failed: journalctl -u nixos-upgrade -n 100. Clears after the next successful run.";
                    };
                  }
                  {
                    # Long enough for an on-device kernel build.
                    alert = "NixosUpgradeStuck";
                    expr = ''node_systemd_unit_state{name="nixos-upgrade.service",state="activating"} == 1'';
                    for = "3h";
                    labels.severity = "warning";
                    annotations = {
                      summary = "${host}: autoUpgrade running for over 3h";
                      description = "Likely a unit blocking the switch: systemctl list-jobs.";
                    };
                  }
                  {
                    alert = "NixosUpgradeNotRunning";
                    expr = ''time() - node_systemd_timer_last_trigger_seconds{name="nixos-upgrade.timer"} > 3 * 3600'';
                    for = "15m";
                    labels.severity = "warning";
                    annotations = {
                      summary = "${host}: autoUpgrade timer hasn't fired in 3h";
                      description = "systemctl status nixos-upgrade.timer";
                    };
                  }
                ];
              }
            ];
          }
        );
        alertmanagers = [
          { static_configs = [ { targets = [ "${am.listenAddress}:${toString am.port}" ]; } ]; }
        ];

        alertmanager = {
          enable = true;
          listenAddress = "127.0.0.1";
          # No HA: the default would also gossip on 0.0.0.0:9094, reachable over the tailnet.
          extraFlags = [ "--cluster.listen-address=" ];
          configText = alertmanagerConfig;
          environmentFile = "/etc/alertmanager/telegram.env";
          # amtool can't see the environment file; the check below fills in stand-ins instead.
          checkConfig = false;
        };
      };

      # The configuration, with stand-in secrets, must pass `amtool check-config` for the system
      # to build.
      system.checks = [
        (pkgs.runCommand "alertmanager-config-check" { nativeBuildInputs = [ am.package ]; } ''
          TELEGRAM_BOT_TOKEN=0:stand-in TELEGRAM_CHAT_ID=1 ${lib.getExe pkgs.envsubst} \
            -i ${pkgs.writeText "alertmanager.yml" alertmanagerConfig} -o alertmanager.yml
          amtool check-config alertmanager.yml
          touch $out
        '')
      ];

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
