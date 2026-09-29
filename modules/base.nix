{ inputs, ... }:
let
  common = {
    nix.settings.experimental-features = "nix-command flakes";
    nix.channel.enable = false;
    nix.gc.automatic = true;
    nixpkgs.config.allowUnfree = true;
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
  };
in
{
  flake.modules = {
    nixos.base = {
      imports = [
        inputs.home-manager.nixosModules.home-manager
        common
      ];
      nix.gc = {
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
      programs.zsh.enable = true;
    };

    darwin.base = {
      imports = [
        inputs.home-manager.darwinModules.home-manager
        common
      ];
    };
  };
}
