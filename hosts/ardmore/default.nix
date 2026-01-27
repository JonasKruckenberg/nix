{
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    # Machine-specific configurations.
    ./bootloader.nix
    ./networking.nix
    ./hardware.nix
    inputs.apple-silicon-support.nixosModules.apple-silicon-support

    ./services/tailscale.nix
  ];

  time.timeZone = "Europe/Berlin";
}
