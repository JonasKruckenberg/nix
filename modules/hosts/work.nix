{
  inputs,
  config,
  withSystem,
  ...
}:
{
  # Work MacBook: user-level only (no nix-darwin), so it needs neither admin rights nor MDM
  # exceptions. Apply with:
  #   nix run home-manager -- switch --flake github:JonasKruckenberg/nix#work
  flake.homeConfigurations.work = withSystem "aarch64-darwin" (
    { pkgs, ... }:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ config.flake.modules.homeManager.work ];
    }
  );

  flake.modules.homeManager.work = {
    imports = with config.flake.modules.homeManager; [
      jonas
      workstation
    ];
    nixpkgs.config.allowUnfree = true;
    programs.home-manager.enable = true;
  };
}
