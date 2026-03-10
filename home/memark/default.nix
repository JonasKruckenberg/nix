{ ... }:
{
  imports = [
    ./shell.nix
    ./git.nix
    ./packages.nix
  ];

  home = {
    username = "memark";
    homeDirectory = "/home/memark";
    stateVersion = "25.11";
  };
}
