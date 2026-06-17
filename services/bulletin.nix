{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [ inputs.bulletin.nixosModules.bulletin ];

  # SMTP credentials live in an agenix secret, decrypted at activation into a root-only file
  # under /run/agenix. The bulletin module feeds it to the service via systemd EnvironmentFile,
  # so the Proton token never lands in the Nix store or the world-readable journal. The file is
  # an env file (KEY=value per line); see secrets/secrets.nix for the recipient keys.
  age.secrets.bulletin-smtp.file = ../secrets/bulletin-smtp.age;

  age.secrets."bulletin-api-admin-key" = {
    file = ../secrets/bulletin-api-admin-key.age;
    owner = "bulletin";
    group = "bulletin";
    mode = "0440";
  };

  services.bulletin = {
    enable = true;

    # Admin API auth key, decrypted by agenix into a bulletin-readable file under /run/agenix
    # (owner/mode set on the secret above); the module reads it at runtime, never the store.
    api.adminKeyFile = config.age.secrets."bulletin-api-admin-key".path;

    # Health on 127.0.0.1:3000, Prometheus on 127.0.0.1:9464, JSON logs to journald
    # (picked up by Alloy → Loki). Email goes out over Proton SMTP.
    email = {
      transport = "smtp";
      # Visible From address; must be an address you own on the Proton account/custom domain.
      from = "bulletin@jonaskruckenberg.de";
      # BULLETIN_SMTP_HOST / USERNAME / PASSWORD (/ PORT / TLS) are read from this env file.
      smtpSecretFile = config.age.secrets.bulletin-smtp.path;
    };

    # Local LLM cluster summarization (upstream's Phase A). Off the punctual path and best-effort: a
    # slow or dead sidecar only yields staler summaries, never a late or wrong digest, and turning the
    # feature off drops cleanly back to the deterministic digest baseline. `enable` is a compile-time
    # switch — it selects the `bulletin-llm` build over the plain binary (there is no runtime flag).
    llm = {
      enable = true;

      # Run the llama.cpp sidecar on-box, bound to loopback (127.0.0.1:8080), so no private content
      # ever leaves the machine (design §12, no egress). The worker is ordered after it but only
      # `wants` it, so a sidecar that's down or slow never blocks the service.
      serveLocally = true;

      # The GGUF is fetched + sha256-verified into /var/lib/bulletin-models on activation (declarative
      # reference; the multi-GB blob stays out of the Nix store and binary cache). To fill these in:
      #   - modelUrl:    a Q4_K_M GGUF, e.g. https://huggingface.co/<repo>/resolve/main/<file>-Q4_K_M.gguf
      #   - modelSha256: the `oid sha256:` (64 hex chars, not SRI) from
      #                  `curl -sL https://huggingface.co/<repo>/raw/main/<file>-Q4_K_M.gguf`
      modelUrl = "https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_K_M.gguf";
      modelSha256 = "00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4";
      model = "Qwen3.5-4B-Q4_K_M.gguf";

      # GPU (Asahi Vulkan) path: run the sidecar on the GPU instead of CPU — same GGUF and model name, so
      # no re-fetch or re-summarization. Requires hardware.graphics.enable on the host (set in
      # hosts/ardmore, which exposes the mesa-asahi-edge Vulkan ICD via apple-silicon-support) plus the
      # llama-cpp unit override below (device groups, shader cache, W^X). Verify it actually initializes
      # Vulkan on the box — llama.cpp on Asahi/honeykrisp is recent and not always smooth.
      package = pkgs.llama-cpp.override { vulkanSupport = true; };
    };
  };

  # GPU (Asahi Vulkan) sidecar plumbing for the nixpkgs services.llama-cpp unit. Upstream already sets
  # PrivateDevices = false (so /dev/dri is visible) and CacheDirectory = llama-cpp, but it runs under
  # ProtectSystem = "strict" + DynamicUser, leaving three Vulkan-specific gaps to close here:
  #
  #   1. Device permission — a DynamicUser belongs to no groups, so it can't open the DRI nodes even
  #      though they're visible. Add `render` (renderD*) and `video` (card*). Needs hardware.graphics
  #      on the host (hosts/ardmore) so the nodes and the Mesa Asahi ICD exist; the NixOS-patched
  #      vulkan-loader auto-discovers the ICD under /run/opengl-driver, which stays readable through
  #      ProtectSystem = "strict". (If discovery ever fails, set VK_DRIVER_FILES in environment below.)
  #   2. Shader cache — only LLAMA_CACHE is set upstream, so Mesa has nowhere to cache compiled shaders.
  #      Point MESA_SHADER_CACHE_DIR at the unit's writable CacheDirectory (/var/cache/llama-cpp).
  #   3. W^X — Mesa's shader JIT needs writable-then-executable pages, which upstream's
  #      MemoryDenyWriteExecute = true forbids (the sidecar dies on an mmap/EPERM at startup); relax it.
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

  # Scrape Bulletin's exporter alongside the node exporter (see services/prometheus.nix).
  services.prometheus.scrapeConfigs = [
    {
      job_name = "bulletin";
      static_configs = [ { targets = [ config.services.bulletin.metrics.addr ]; } ];
    }
  ];
}
