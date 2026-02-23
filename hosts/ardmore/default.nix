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

  hardware.asahi.peripheralFirmwareDirectory = ./firmware;

  time.timeZone = "Europe/Berlin";

  system.stateVersion = "25.11";
}
