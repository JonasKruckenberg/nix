{ inputs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./deploy.nix
    inputs.apple-silicon-support.nixosModules.apple-silicon-support
    ../../services/tailscale.nix
    ../../services/grafana.nix
    ../../services/prometheus.nix
    ../../services/loki.nix
    ../../services/alloy.nix
  ];

  networking.hostName = "ardmore";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.systemd-boot.configurationLimit = 10;

  # allow non-root perf
  boot.kernel.sysctl."kernel.perf_event_paranoid" = -1;
  boot.kernel.sysctl."kernel.kptr_restrict" = lib.mkForce 0;

  hardware.asahi.peripheralFirmwareDirectory = ./firmware;

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
