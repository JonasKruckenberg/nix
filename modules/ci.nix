{ lib, config, ... }:
{
  # Every configuration becomes a check on its own system, so `nix flake check` on an
  # aarch64-linux runner builds the NixOS hosts and on an aarch64-darwin runner builds the
  # nix-darwin hosts and standalone home-manager profiles. Adding a host adds a check.
  perSystem =
    { system, ... }:
    {
      checks =
        let
          onSystem = lib.filterAttrs (_: c: c.pkgs.stdenv.hostPlatform.system == system);
          systems = onSystem ((config.flake.nixosConfigurations or { }) // (config.flake.darwinConfigurations or { }));
          homes = onSystem (config.flake.homeConfigurations or { });
        in
        lib.mapAttrs' (n: c: lib.nameValuePair "system-${n}" c.config.system.build.toplevel) systems
        // lib.mapAttrs' (n: c: lib.nameValuePair "home-${n}" c.activationPackage) homes;
    };
}
