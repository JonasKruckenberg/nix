{ pkgs, ... }:
{
  users.users.jonaskruckenberg = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "trusted"
    ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  users.mutableUsers = true;

  nix.gc = {
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}
