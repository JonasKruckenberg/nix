{ inputs, config, ... }:
{
  # Private MacBook. Apply with:
  #   sudo darwin-rebuild switch --flake github:JonasKruckenberg/nix#goldwater
  flake.darwinConfigurations.goldwater = inputs.nix-darwin.lib.darwinSystem {
    modules = [ config.flake.modules.darwin.goldwater ];
  };

  flake.modules.darwin.goldwater = {
    imports = with config.flake.modules.darwin; [
      base
      jonas
      workstation
    ];

    networking.hostName = "goldwater";
    nixpkgs.hostPlatform = "aarch64-darwin";
    system.stateVersion = 6;
  };
}
