{ ... }:
{
  imports = [
    ./shell.nix
    ./git.nix
    ./packages.nix
  ];

  home = {
    username = "daxhuiberts";
    homeDirectory = "/home/daxhuiberts";
    stateVersion = "25.11";
  };
}
