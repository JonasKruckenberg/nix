{ inputs, pkgs, config, ... }:
let
  nlPkg = inputs.nativelink.packages.${pkgs.stdenv.hostPlatform.system}.nativelink;

  # NativeLink JSON5 configuration.
  #
  # Single-machine all-in-one mode: CAS + action cache + remote execution.
  # Public gRPC endpoint on :50051, internal worker API on :50061.
  #
  # Clients connect with:
  #   --remote_cache=grpc://<tailscale-ip>:50051
  #   --remote_instance_name=main
  nlConfig = pkgs.writeText "nativelink.json5" ''
    {
      stores: [
        // Action cache: maps action digests → result digests
        {
          name: "AC_MAIN_STORE",
          filesystem: {
            content_path: "/var/lib/nativelink/ac/content",
            temp_path:    "/var/lib/nativelink/ac/tmp",
            eviction_policy: {
              max_bytes: 1000000000, // 1 GB
            },
          },
        },

        // Content-addressable store: the worker's fast_slow store.
        // The fast (filesystem) tier is required for the worker to hardlink
        // build inputs into the work directory without copying data.
        {
          name: "CAS_MAIN_STORE",
          fast_slow: {
            fast: {
              filesystem: {
                content_path: "/var/lib/nativelink/cas/content",
                temp_path:    "/var/lib/nativelink/cas/tmp",
                eviction_policy: {
                  max_bytes: 10000000000, // 10 GB
                },
              },
            },
            // No shared remote backend in single-machine mode.
            slow: {
              noop: {},
            },
          },
        },
      ],

      schedulers: [
        {
          name: "MAIN_SCHEDULER",
          simple: {
            supported_platform_properties: {
              cpu_count:    "minimum",
              memory_kb:    "minimum",
              network_kbps: "minimum",
              disk_read_iops:  "minimum",
              disk_read_bps:   "minimum",
              disk_write_iops: "minimum",
              disk_write_bps:  "minimum",
              gpu_count:  "minimum",
              gpu_model:  "exact",
              cpu_arch:   "exact",
              cpu_model:  "exact",
              OSFamily:          "priority",
              "container-image": "priority",
              ISA:                    "exact",
              InputRootAbsolutePath: "ignore", // used by chromium builds
            },
          },
        },
      ],

      workers: [
        {
          local: {
            worker_api_endpoint: {
              uri: "grpc://127.0.0.1:50061",
            },
            // Must reference the fast_slow store so the worker can hardlink
            // files from the fast (filesystem) tier into the work directory.
            cas_fast_slow_store: "CAS_MAIN_STORE",
            upload_action_result: {
              ac_store: "AC_MAIN_STORE",
            },
            work_directory: "/var/lib/nativelink/work",
            platform_properties: {
              cpu_count:  { values: ["8"] },
              memory_kb:  { values: ["16000000"] }, // 16 GB
              network_kbps: { values: ["100000"] },
              cpu_arch:  { values: ["aarch64"] },
              OSFamily:  { values: ["Linux"] },
              "container-image": { values: [""] },
              ISA:       { values: ["aarch64"] },
            },
          },
        },
      ],

      servers: [
        // Public endpoint — accessible from the Tailscale network.
        {
          name: "public",
          listener: {
            http: {
              socket_address: "0.0.0.0:50051",
            },
          },
          services: {
            cas: [
              { instance_name: "main", cas_store: "CAS_MAIN_STORE" },
            ],
            ac: [
              { instance_name: "main", ac_store: "AC_MAIN_STORE" },
            ],
            execution: [
              {
                instance_name: "main",
                cas_store:     "CAS_MAIN_STORE",
                scheduler:     "MAIN_SCHEDULER",
              },
            ],
            capabilities: [
              {
                instance_name: "main",
                remote_execution: { scheduler: "MAIN_SCHEDULER" },
              },
            ],
            bytestream: [
              { instance_name: "main", cas_store: "CAS_MAIN_STORE" },
            ],
          },
        },

        // Internal endpoint — worker API and admin, localhost only.
        {
          name: "internal",
          listener: {
            http: {
              socket_address: "127.0.0.1:50061",
            },
          },
          services: {
            worker_api: { scheduler: "MAIN_SCHEDULER" },
            admin:  {},
            health: {},
          },
        },
      ],

      global: {
        max_open_files: 24576,
      },
    }
  '';
in
{
  # Dedicated non-root user for the nativelink daemon.
  users.users.nativelink = {
    isSystemUser = true;
    group = "nativelink";
    description = "NativeLink build cache service user";
  };
  users.groups.nativelink = { };

  # State directories under /var/lib/nativelink.
  systemd.tmpfiles.rules = [
    "d /var/lib/nativelink              0750 nativelink nativelink -"
    "d /var/lib/nativelink/ac           0750 nativelink nativelink -"
    "d /var/lib/nativelink/ac/content   0750 nativelink nativelink -"
    "d /var/lib/nativelink/ac/tmp       0750 nativelink nativelink -"
    "d /var/lib/nativelink/cas          0750 nativelink nativelink -"
    "d /var/lib/nativelink/cas/content  0750 nativelink nativelink -"
    "d /var/lib/nativelink/cas/tmp      0750 nativelink nativelink -"
    "d /var/lib/nativelink/work         0750 nativelink nativelink -"
  ];

  systemd.services.nativelink = {
    description = "NativeLink remote build cache and execution server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      RUST_LOG = "warn";
      # Ship metrics to the local OpenTelemetry collector via gRPC OTLP.
      OTEL_EXPORTER_OTLP_ENDPOINT = "http://127.0.0.1:4317";
      OTEL_EXPORTER_OTLP_PROTOCOL = "grpc";
      OTEL_SERVICE_NAME = "nativelink";
    };

    serviceConfig = {
      ExecStart = "${nlPkg}/bin/nativelink ${nlConfig}";
      User = "nativelink";
      Group = "nativelink";

      Restart = "on-failure";
      RestartSec = "5s";

      LimitNOFILE = 24576;

      # Basic sandboxing — allow only the state directory.
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/nativelink" ];
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  # OpenTelemetry Collector: receives OTLP from NativeLink and exposes a
  # Prometheus scrape endpoint that the local Prometheus instance scrapes.
  services.opentelemetry-collector = {
    enable = true;
    # otelcol-contrib ships the prometheusexporter required here.
    package = pkgs.opentelemetry-collector-contrib;
    settings = {
      receivers.otlp.protocols = {
        grpc.endpoint = "127.0.0.1:4317";
        http.endpoint = "127.0.0.1:4318";
      };
      processors.batch = { };
      exporters.prometheus.endpoint = "127.0.0.1:9091";
      service.pipelines.metrics = {
        receivers = [ "otlp" ];
        processors = [ "batch" ];
        exporters = [ "prometheus" ];
      };
    };
  };

  # Add NativeLink metrics (via OTEL collector) to Prometheus scrape targets.
  services.prometheus.scrapeConfigs = [
    {
      job_name = "nativelink";
      static_configs = [
        { targets = [ "127.0.0.1:9091" ]; }
      ];
    }
  ];
}
