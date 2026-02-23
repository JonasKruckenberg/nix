{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    easy-hosts.url = "github:tgirlcloud/easy-hosts";

    apple-silicon-support = {
      url = "github:nix-community/nixos-apple-silicon/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.easy-hosts.flakeModule
        inputs.treefmt-nix.flakeModule
        #        inputs.home-manager.flakeModules.home-manager

        ./modules
        ./hosts
      ];

      systems = [
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        {
          system,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
            };
          };

          treefmt = {
            programs = {
              keep-sorted.enable = true;
              shellcheck.enable = true;

              #jsonfmt.enable = true;
              #jsonfmt.excludes = [ ".zed/settings.json" ];

              # justfile
              just.enable = true;

              # .md files
              mdformat.enable = true;
              mdformat.settings.wrap = 120;

              # .nix files
              deadnix = {
                enable = true;
                no-underscore = true;
              };

              # nixf-diagnose.enable = true;
              nixfmt.enable = true;
              nixfmt.indent = 2;
              nixfmt.width = 120;
              statix.enable = true;

              # .toml files
              taplo.enable = true;

              # .yml/.yaml files
              yamlfmt.enable = true;
            };
          };
        };
    };
}
