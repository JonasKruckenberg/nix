{ inputs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./deploy.nix
    inputs.apple-silicon-support.nixosModules.apple-silicon-support
    inputs.agenix.nixosModules.default
    ../../services/tailscale.nix
    ../../services/grafana.nix
    ../../services/prometheus.nix
    ../../services/loki.nix
    ../../services/alloy.nix
  ];

  networking.hostName = "ardmore";

  # agenix decryption identity. This host uses Tailscale SSH with OpenSSH disabled, so agenix
  # can't auto-derive an identity from services.openssh.hostKeys — point it at a dedicated
  # ed25519 key generated once on the box (see secrets/secrets.nix for the matching recipient).
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.systemd-boot.configurationLimit = 10;
  # Apple Silicon has read-only EFI vars, and systemd >=257 ignores `--no-variables`
  # in `bootctl update`, so it fails fatally. `--graceful` makes that write non-fatal.
  boot.loader.systemd-boot.graceful = true;

  # allow non-root perf
  boot.kernel.sysctl."kernel.perf_event_paranoid" = -1;
  boot.kernel.sysctl."kernel.kptr_restrict" = lib.mkForce 0;

  hardware.asahi.peripheralFirmwareDirectory = ./firmware;

  # Build /run/opengl-driver from the asahi-overlaid Mesa so the GPU stack — and crucially the Mesa
  # Asahi (honeykrisp) Vulkan ICD — exists on the box. apple-silicon-support only sets
  # hardware.graphics.package; it never flips `.enable`, so without this the Vulkan loader finds no
  # ICD and the llama-cpp sidecar (services/bulletin.nix) can't initialize Vulkan. The NixOS-patched
  # vulkan-loader then auto-discovers the ICD under /run/opengl-driver/share/vulkan/icd.d.
  hardware.graphics.enable = true;

  time.timeZone = "Europe/Berlin";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ALL = "en_US.UTF-8";
  };

  console = {
    keyMap = "de-latin1-nodeadkeys";
  };

  system.stateVersion = "25.11";
}
