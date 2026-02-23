{ lib, ... }:
{
  networking.hostName = "vermeer";

  # Boot loader config is format-dependent; nixos-generators handles this per-format.
  boot.loader.grub.enable = lib.mkDefault false;

  # Dummy root filesystem for evaluation; overridden by nixos-generators formats.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  system.stateVersion = "25.11";
}
