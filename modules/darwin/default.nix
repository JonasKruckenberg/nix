{ pkgs, ... }:
{
  imports = [
    ./system-defaults.nix
  ];

  users.knownUsers = [ "jonaskruckenberg" ];
  users.users.jonaskruckenberg = {
    shell = pkgs.zsh;
    uid = 1001;
  };
  system.primaryUser = "jonaskruckenberg";
}
