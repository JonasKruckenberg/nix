{
  description = "Jonas' multi-host Nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-silicon-support = {
      url = "github:nix-community/nixos-apple-silicon/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      nix-darwin,
      home-manager,
      ...
    }:
    let
      commonModules = [
        ./modules/common
      ];

      homeManagerConfig = {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.jonaskruckenberg = import ./home/jonaskruckenberg;
        home-manager.users.memark = import ./home/memark;
        home-manager.users.daxhuiberts = import ./home/daxhuiberts;
        home-manager.extraSpecialArgs = { inherit inputs; };
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-linux"
        "aarch64-darwin"
      ];

      imports = [
        inputs.treefmt-nix.flakeModule
      ];

      perSystem =
        { system, ... }:
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          treefmt = {
            programs = {
              nixfmt.enable = true;
              nixfmt.indent = 2;
              nixfmt.width = 120;
              deadnix = {
                enable = true;
                no-underscore = true;
              };
              statix.enable = true;
              keep-sorted.enable = true;
              shellcheck.enable = true;
              just.enable = true;
              taplo.enable = true;
              yamlfmt.enable = true;
            };
          };
        };

      flake = {
        nixosConfigurations.ardmore = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit inputs; };
          modules = commonModules ++ [
            ./modules/nixos
            ./hosts/ardmore
            home-manager.nixosModules.home-manager
            homeManagerConfig
          ];
        };

        darwinConfigurations.goldwater = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit inputs; };
          modules = commonModules ++ [
            ./modules/darwin
            ./hosts/goldwater
            home-manager.darwinModules.home-manager
            homeManagerConfig
          ];
        };

        nixosConfigurations.vermeer = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit inputs; };
          modules = commonModules ++ [
            ./modules/nixos
            ./hosts/vermeer
          ];
        };
      };
    };
}
