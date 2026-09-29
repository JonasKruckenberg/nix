{ config, ... }:
let
  name = "daxhuiberts";
in
{
  flake.modules = {
    nixos.daxhuiberts =
      { pkgs, ... }:
      {
        users.users.${name} = {
          isNormalUser = true;
          shell = pkgs.zsh;
        };
        home-manager.users.${name} = config.flake.modules.homeManager.daxhuiberts;
      };

    homeManager.daxhuiberts = {
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
