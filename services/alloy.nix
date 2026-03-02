{ ... }:
{
  services.alloy.enable = true;

  # The default configPath is /etc/alloy; all *.alloy files in that directory are loaded.
  # The module already adds the service to the systemd-journal group, so no extra user config needed.
  environment.etc."alloy/config.alloy".text = ''
    // Promote selected systemd journal fields to Loki stream labels.
    // Fields prefixed with __ are internal and dropped by default.
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

    // Tail the local systemd journal and forward entries to Loki.
    loki.source.journal "read" {
      forward_to    = [loki.write.local.receiver]
      relabel_rules = loki.relabel.journal.rules
      labels        = { job = "systemd-journal" }
    }

    // Push to the Loki instance running on the same host.
    loki.write "local" {
      endpoint {
        url = "http://127.0.0.1:3100/loki/api/v1/push"
      }
    }
  '';
}
