{ pkgs, ... }:
{
  imports = [
    ./shell.nix
    ./git.nix
    ./packages.nix
    ./darwin.nix
  ];

  home = {
    username = "jonaskruckenberg";
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/jonaskruckenberg" else "/home/jonaskruckenberg";
    stateVersion = "25.11";
  };
}
