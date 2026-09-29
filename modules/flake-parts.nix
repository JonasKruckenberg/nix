{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.treefmt-nix.flakeModule
  ];

  systems = [
    "aarch64-linux"
    "aarch64-darwin"
  ];

  perSystem = {
    treefmt.programs = {
      nixfmt.enable = true;
      nixfmt.width = 120;
      deadnix.enable = true;
      statix.enable = true;
      yamlfmt.enable = true;
    };
  };
}
