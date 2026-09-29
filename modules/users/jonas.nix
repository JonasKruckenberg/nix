{ config, ... }:
let
  name = "jonaskruckenberg";
  identity = {
    name = "JonasKruckenberg";
    email = "iterpre@protonmail.com";
  };
in
{
  flake.modules = {
    nixos.jonas =
      { pkgs, ... }:
      {
        users.users.${name} = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "trusted"
          ];
          shell = pkgs.zsh;
        };
        home-manager.users.${name} = config.flake.modules.homeManager.jonas;
      };

    darwin.jonas =
      { pkgs, ... }:
      {
        users.knownUsers = [ name ];
        users.users.${name} = {
          shell = pkgs.zsh;
          uid = 1001;
          home = "/Users/${name}";
        };
        system.primaryUser = name;
        home-manager.users.${name} = config.flake.modules.homeManager.jonas;
      };

    homeManager.jonas =
      { pkgs, ... }:
      {
        imports = with config.flake.modules.homeManager; [
          shell
          dev
        ];

        home = {
          username = name;
          homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${name}" else "/home/${name}";
          stateVersion = "25.11";
          packages = with pkgs; [
            croc
            claude-code
            fastfetch
          ];
        };

        programs.git.settings.user = identity;
        programs.gh.gitCredentialHelper.enable = true;

        programs.jujutsu = {
          enable = true;
          settings = {
            user = identity;
            git.write-change-id-header = true;
            signing = {
              behavior = "own";
              backend = "ssh";
              key = "~/.ssh/id_ed25519.pub";
            };
          };
        };
      };
  };
}
