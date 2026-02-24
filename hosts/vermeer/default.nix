{ lib, ... }:
{
  imports = [
    ../../services/tailscale.nix
  ];

  networking.hostName = "vermeer";

  # Boot loader config is format-dependent; overridden per image variant.
  boot.loader.grub.enable = lib.mkDefault false;

  # Dummy root filesystem for evaluation; overridden per image variant.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # services.openssh = {
  #   enable = true;
  #   settings.PermitRootLogin = "prohibit-password";
  # };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  system.stateVersion = "25.11";
}
