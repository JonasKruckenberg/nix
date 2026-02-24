{ inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    inputs.apple-silicon-support.nixosModules.apple-silicon-support
    ../../services/tailscale.nix
  ];

  networking.hostName = "ardmore";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.systemd-boot.configurationLimit = 10;

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
