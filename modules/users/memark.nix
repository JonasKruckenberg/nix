{ config, ... }:
let
  name = "memark";
in
{
  flake.modules = {
    nixos.memark =
      { pkgs, ... }:
      {
        users.users.${name} = {
          isNormalUser = true;
          shell = pkgs.zsh;
        };
        home-manager.users.${name} = config.flake.modules.homeManager.memark;
      };

    homeManager.memark = {
      imports = with config.flake.modules.homeManager; [
        shell
        dev
      ];
      home = {
        username = name;
        homeDirectory = "/home/${name}";
        stateVersion = "25.11";
      };
    };
  };
}
