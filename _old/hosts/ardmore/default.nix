{ inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    inputs.apple-silicon-support.nixosModules.apple-silicon-support
  ];

  networking.hostName = "ardmore";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  hardware.asahi.peripheralFirmwareDirectory = ./firmware;

  time.timeZone = "Europe/Berlin";

  system.stateVersion = "25.11";
}
