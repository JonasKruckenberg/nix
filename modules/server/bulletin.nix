{ inputs, ... }:
{
  flake.modules.nixos.bulletin =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        inputs.agenix.nixosModules.default
        inputs.bulletin.nixosModules.bulletin
      ];

      # Secrets are decrypted by agenix at activation into /run/agenix; nothing lands in the store
      # or the journal. Recipients live in secrets/secrets.nix.
      age.secrets.bulletin-smtp.file = ../../secrets/bulletin-smtp.age;
      age.secrets.bulletin-api-admin-key = {
        file = ../../secrets/bulletin-api-admin-key.age;
        owner = "bulletin";
        group = "bulletin";
        mode = "0440";
      };
      age.secrets.bulletin-github = {
        file = ../../secrets/bulletin-github.age;
        owner = "bulletin";
        group = "bulletin";
        mode = "0440";
      };

      services.bulletin = {
        enable = true;
        api.adminKeyFile = config.age.secrets.bulletin-api-admin-key.path;
        github.secretFile = config.age.secrets.bulletin-github.path;

        # Health on 127.0.0.1:3000, Prometheus on 127.0.0.1:9464, JSON logs to journald.
        email = {
          transport = "smtp";
          from = "bulletin@jonaskruckenberg.de";
          # BULLETIN_SMTP_HOST / USERNAME / PASSWORD (/ PORT / TLS) come from this env file.
          smtpSecretFile = config.age.secrets.bulletin-smtp.path;
        };

        # Local LLM cluster summarization, best-effort: a slow or dead sidecar only yields staler
        # summaries. `enable` is compile-time and selects the `bulletin-llm` build.
        llm = {
          enable = true;
          # llama.cpp sidecar on-box, loopback only; the worker `wants` it but never blocks on it.
          serveLocally = true;
          # The GGUF is fetched and sha256-verified into /var/lib/bulletin-models on activation.
          modelUrl = "https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_K_M.gguf";
          modelSha256 = "00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4";
          model = "Qwen3.5-4B-Q4_K_M.gguf";
          # Asahi Vulkan path; needs hardware.graphics.enable on the host and the unit override below.
          package = pkgs.llama-cpp.override { vulkanSupport = true; };
        };
      };

      # Vulkan plumbing for the nixpkgs llama-cpp unit, which runs under ProtectSystem=strict with a
      # DynamicUser: grant the DRI nodes, give Mesa a shader cache, and relax W^X for its JIT.
      systemd.services.llama-cpp = {
        environment.MESA_SHADER_CACHE_DIR = "/var/cache/llama-cpp";
        serviceConfig = {
          SupplementaryGroups = [
            "render"
            "video"
          ];
          MemoryDenyWriteExecute = lib.mkForce false;
        };
      };

      services.prometheus.scrapeConfigs = [
        {
          job_name = "bulletin";
          static_configs = [ { targets = [ config.services.bulletin.metrics.addr ]; } ];
        }
      ];
    };
}
