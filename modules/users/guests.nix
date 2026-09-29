{ config, lib, ... }:
let
  # Other people with an account on ardmore.
  guests = [
    "memark"
    "daxhuiberts"
  ];

  nixosUser =
    name:
    { pkgs, ... }:
    {
      users.users.${name} = {
        isNormalUser = true;
        shell = pkgs.zsh;
      };
      home-manager.users.${name} = config.flake.modules.homeManager.${name};
    };

  homeUser = name: {
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
in
{
  flake.modules = {
    nixos = lib.genAttrs guests nixosUser;
    homeManager = lib.genAttrs guests homeUser;
  };
}
