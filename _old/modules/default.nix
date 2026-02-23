{ inputs, flake, ... }:
{
  flake = {
    commonModules = import ./common { inherit inputs flake; };
    darwinModules = import ./darwin { inherit inputs; };
    nixosModules = import ./nixos { inherit inputs; };
  };
}
